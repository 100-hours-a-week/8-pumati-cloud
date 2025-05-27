#!/bin/bash
echo "${project_name}-${environment} 프론트엔드 서버 설정 스크립트"

# 환경 변수 설정
SERVER_TYPE="${project_name}-${environment}-frontend"
ENV_SECRET_NAME="${frontend_env_secret_name}"
REGION="${aws_region}"

# 환경 변수로 디스코드 웹훅 URL 설정
DISCORD_WEBHOOK="${discord_webhook_url}"

# 로그 기록 함수 정의
log_message() {
  local message="$1"
  local timestamp=$(TZ='Asia/Seoul' date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] $message" | tee -a /var/log/frontend-deploy.log
}

# 기본 패키지 설치
log_message "기본 패키지 업데이트 및 설치 중..."
apt-get update -y
apt-get install -y jq curl git

# Node.js 및 pnpm 설치
log_message "Node.js v23.9.0 설치 중..."
curl -fsSL https://deb.nodesource.com/setup_23.x | bash -
apt-get install -y nodejs
if [ $? -ne 0 ]; then
  log_message "❌ Node.js 설치 실패!"
  exit 1
fi

# Node.js 버전 확인
node_version=$(node -v)
log_message "✅ Node.js $node_version 설치 완료"

# pnpm 설치
log_message "pnpm 설치 중..."
npm install -g pnpm
if [ $? -ne 0 ]; then
  log_message "❌ pnpm 설치 실패!"
  exit 1
fi

# pnpm 버전 확인
pnpm_version=$(pnpm --version)
log_message "✅ pnpm $pnpm_version 설치 완료"

# 스팟 인스턴스 중단 알림 모니터링 스크립트 생성
cat > /usr/local/bin/spot-termination-handler.sh << 'EOF'
#!/bin/bash

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
INSTANCE_TYPE=$(curl -s http://169.254.169.254/latest/meta-data/instance-type)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
DISCORD_WEBHOOK="DISCORD_WEBHOOK_PLACEHOLDER"
SERVER_TYPE="SERVER_TYPE_PLACEHOLDER"

# 무한 루프로 스팟 인스턴스 중단 공지 확인
while true; do
  # 스팟 인스턴스 중단 공지 확인
  NOTICE=$(curl -s http://169.254.169.254/latest/meta-data/spot/termination-time)
  
  # 중단 공지가 있는 경우
  if [[ $NOTICE != "" && $NOTICE != "Not Found" ]]; then
    # 디스코드로 알림 전송
    MESSAGE=":warning: **frontend dev 인스턴스 중단 예정** :warning:\n- 서버 유형: $SERVER_TYPE\n- 인스턴스 ID: $INSTANCE_ID\n- 인스턴스 타입: $INSTANCE_TYPE\n- 가용 영역: $AZ\n- 중단 예정 시간: $NOTICE"
    
    curl -H "Content-Type: application/json" \
         -d "{\"content\": \"$MESSAGE\"}" \
         $DISCORD_WEBHOOK
    
    # 로그 남기기
    echo "$(date): Spot instance $INSTANCE_ID termination notice received. Sent alert to Discord." | tee -a /var/log/spot-termination.log
    
    # 알림 후 종료 (반복 알림 방지)
    break
  fi
  
  # 30초 대기 후 다시 확인
  sleep 30
done
EOF

# 플레이스홀더 값을 실제 값으로 대체
sed -i "s|DISCORD_WEBHOOK_PLACEHOLDER|$DISCORD_WEBHOOK|g" /usr/local/bin/spot-termination-handler.sh
sed -i "s|SERVER_TYPE_PLACEHOLDER|$SERVER_TYPE|g" /usr/local/bin/spot-termination-handler.sh

# 스크립트 실행 권한 부여
chmod +x /usr/local/bin/spot-termination-handler.sh

# systemd 서비스 생성
cat > /etc/systemd/system/spot-termination-handler.service << EOF
[Unit]
Description=Spot Instance Termination Notice Handler
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/spot-termination-handler.sh
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

# 서비스 활성화 및 시작
systemctl daemon-reload
systemctl enable spot-termination-handler.service
systemctl start spot-termination-handler.service

# AWS CLI 설치 (공식 방법)
log_message "AWS CLI 설치 중..."
apt-get update -y
apt-get install -y curl unzip

# AWS CLI가 설치되어 있는지 확인
if ! command -v aws &> /dev/null; then
  log_message "AWS CLI v2 다운로드 및 설치 중..."
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip -q awscliv2.zip
  ./aws/install
  rm -rf aws awscliv2.zip
  
  # 설치 확인
  if ! command -v aws &> /dev/null; then
    log_message "❌ AWS CLI 설치 실패!"
    exit 1
  fi
fi

# AWS CLI 버전 확인
aws_version=$(aws --version 2>&1)
log_message "✅ AWS CLI 설치 확인: $aws_version"

# AWS 리전 설정
aws configure set region $REGION

# AWS Secrets Manager에서 .env 파일 내용 가져오기
log_message "AWS Secrets Manager에서 .env 파일 가져오는 중..."
ENV_CONTENT=$(aws secretsmanager get-secret-value \
  --secret-id $ENV_SECRET_NAME \
  --region $REGION \
  --query 'SecretString' \
  --output text)

# .env 파일 생성
log_message ".env 파일 생성 중..."
mkdir -p /home/ubuntu
echo "$ENV_CONTENT" > /home/ubuntu/.env
if [ $? -ne 0 ]; then
  log_message "❌ .env 파일 생성 실패!"
  exit 1
fi
log_message "✅ .env 파일 생성 완료"

# Nginx 설치
log_message "Nginx 설치 중..."
apt-get install -y nginx

# Nginx 기본 설정 제거
rm -f /etc/nginx/sites-enabled/default

# Nginx 설정 파일 생성
log_message "Nginx 설정 파일 생성 중..."
cat > /etc/nginx/sites-available/frontend << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

# 심볼릭 링크 생성
ln -sf /etc/nginx/sites-available/frontend /etc/nginx/sites-enabled/

# Nginx 설정 테스트
nginx -t

# Nginx 재시작
systemctl restart nginx
log_message "✅ Nginx 설정 완료"

# 재배포 스크립트 생성
log_message "재배포 스크립트 생성 중..."
cat > /home/ubuntu/deploy-fe.sh << 'EOFSCRIPT'
#!/bin/bash

# 로그 기록 함수 정의
log_message() {
  local message="$1"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] $message" | tee -a /var/log/frontend-redeploy.log
}

log_message "프론트엔드 수동 재배포 시작"

# 0. 기존 프론트엔드 서버 종료
log_message "기존 프론트엔드 서버 중지 중..."
EXIST_PID=$(sudo ss -tulpn | grep ':3000' | awk -F 'pid=' '{print $2}' | cut -d',' -f1)
if [ -n "$EXIST_PID" ]; then
  kill -15 $EXIST_PID
  # 프로세스가 정상적으로 종료되길 기다림
  for i in {1..5}; do
    if ! ps -p $EXIST_PID > /dev/null; then
      break
    fi
    log_message "프로세스 종료 대기 중... ($i/5)"
    sleep 1
  done
  
  # 프로세스가 여전히 실행 중이면 강제 종료
  if ps -p $EXIST_PID > /dev/null; then
    log_message "강제 종료 실행: PID $EXIST_PID"
    kill -9 $EXIST_PID
  fi
  log_message "➡️ PID $EXIST_PID 종료됨"
else
  log_message "ℹ️ 실행 중인 프론트엔드 서버 없음"
fi

# 1. 기존 프로젝트 디렉토리 확인 및 삭제
log_message "기존 프로젝트 디렉토리 확인 중..."
cd /home/ubuntu || {
  log_message "❌ /home/ubuntu 디렉토리 접근 실패!"
  exit 1
}

if [ -d "8-pumati-fe" ]; then
  log_message "기존 8-pumati-fe 디렉토리 삭제 중..."
  rm -rf 8-pumati-fe
  if [ $? -ne 0 ]; then
    log_message "❌ 기존 디렉토리 삭제 실패!"
    exit 1
  fi
fi

# 2. 프로젝트 클론
log_message "dev 브랜치에서 8-pumati-fe 클론 중..."
git clone -b dev https://github.com/100-hours-a-week/8-pumati-fe.git
if [ $? -ne 0 ]; then
  log_message "❌ 프로젝트 클론 실패!"
  exit 1
fi
log_message "✅ 프로젝트 클론 완료"

# 3. .env 복사
log_message ".env 파일을 프로젝트로 복사 중..."
cp /home/ubuntu/.env /home/ubuntu/8-pumati-fe/.env
if [ $? -ne 0 ]; then
  log_message "❌ .env 파일 복사 실패!"
  exit 1
fi
log_message "✅ .env 파일 복사 완료"

# 4. 프로젝트 디렉토리로 이동
log_message "프로젝트 디렉토리로 이동 중..."
cd /home/ubuntu/8-pumati-fe || {
  log_message "❌ 프로젝트 디렉토리 접근 실패!"
  exit 1
}

# 5. 의존성 설치
log_message "의존성 설치 중..."
pnpm install > install.log 2>&1
if [ $? -ne 0 ]; then
  log_message "❌ 의존성 설치 실패! install.log 확인 필요"
  cat install.log | tail -n 20 >> /var/log/frontend-redeploy.log
  exit 1
fi
log_message "✅ 의존성 설치 완료"

# 6. 빌드
log_message "프로젝트 빌드 중..."
pnpm build > build.log 2>&1
if [ $? -ne 0 ]; then
  log_message "❌ 빌드 실패! build.log 확인 필요"
  cat build.log | tail -n 20 >> /var/log/frontend-redeploy.log
  exit 1
fi
log_message "✅ 빌드 완료"

# 7. 서버 실행 (백그라운드)
log_message "프론트엔드 서버 시작 중..."
nohup pnpm start > pnpm.log 2>&1 &
SERVER_PID=$!
disown

# 8. 실행 확인
log_message "프론트엔드 서버 프로세스 확인 중..."
sleep 5
if ps -p $SERVER_PID > /dev/null; then
  log_message "✅ 프론트엔드 서버가 PID $SERVER_PID로 실행 중"
else
  log_message "⚠️ 서버 시작 실패! pnpm.log 확인 필요:"
  cat pnpm.log | tail -n 50 >> /var/log/frontend-redeploy.log
  exit 1
fi

# 9. 헬스 체크 간소화
log_message "서버 헬스 체크 중..."
sleep 10  # 서버가 시작할 시간을 충분히 줌

# 단일 헬스 체크 시도 (포트 3000 기준)
if curl -s http://localhost:3000 > /dev/null; then
  log_message "✅ 프론트엔드 서버 응답 확인"
else
  log_message "⚠️ 프론트엔드 서버가 응답하지 않습니다. 자세한 내용은 pnpm.log를 확인하세요."
  cat pnpm.log | tail -n 50 >> /var/log/frontend-redeploy.log
  # 경고만 표시하고 종료하지 않음 (서버는 계속 실행)
fi

log_message "프론트엔드 서버 재배포 완료!"
echo "프론트엔드 서버 재배포가 완료되었습니다!"
EOFSCRIPT

# 실행 권한 부여
chmod +x /home/ubuntu/deploy-fe.sh
log_message "✅ 재배포 스크립트 생성 완료: /home/ubuntu/deploy-fe.sh"

# 재배포 스크립트 실행하여 초기 배포 완료
log_message "초기 배포 실행 중..."
/home/ubuntu/deploy-fe.sh

log_message "✅ 프론트엔드 서버 초기 설정 완료"