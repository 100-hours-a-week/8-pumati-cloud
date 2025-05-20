#!/bin/bash
echo "${project_name}-${environment} 백엔드 서버 설정 스크립트"

# 환경 변수로 디스코드 웹훅 URL 설정
DISCORD_WEBHOOK="${discord_webhook_url}"
SERVER_TYPE="${project_name}-${environment}-backend"

# 기본 패키지 설치
yum update -y
yum install -y jq curl

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
    MESSAGE=":warning: **backend dev 인스턴스 중단 예정** :warning:\n- 서버 유형: $SERVER_TYPE\n- 인스턴스 ID: $INSTANCE_ID\n- 인스턴스 타입: $INSTANCE_TYPE\n- 가용 영역: $AZ\n- 중단 예정 시간: $NOTICE"
    
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

# 여기에 기존 백엔드 서버 설정 스크립트 추가