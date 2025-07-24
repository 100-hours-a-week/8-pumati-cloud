#!/bin/bash
# MongoDB 7.0 설치 및 설정 스크립트 - Ubuntu Linux
# Project: ${project_name}
# Environment: ${environment}

# 로그 파일 설정
LOG_FILE="/var/log/mongodb-install.log"
exec > >(tee -a $LOG_FILE)
exec 2>&1

echo "=== MongoDB 7.0 단일 인스턴스 설치 시작: $(date) ==="

# 시스템 업데이트
echo "시스템 패키지 업데이트 중..."
apt-get update -y
apt-get upgrade -y

# 필수 패키지 설치
echo "필수 패키지 설치 중..."
apt-get install -y wget curl gnupg2 software-properties-common ca-certificates lsb-release net-tools

# MongoDB GPG 키 추가 (MongoDB 7.0용)
echo "MongoDB GPG 키 추가 중..."
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg

# MongoDB 저장소 추가 (Ubuntu용)
echo "MongoDB 저장소 추가 중..."
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-7.0.list

# 저장소 업데이트
echo "저장소 업데이트 중..."
apt-get update -y

# MongoDB 설치
echo "MongoDB 7.0 설치 중..."
apt-get install -y mongodb-org

# MongoDB 서비스가 자동으로 시작되는 것을 방지 (설정 후 시작)
systemctl stop mongod || true
systemctl disable mongod || true

# MongoDB 데이터 디렉토리 생성 및 권한 설정
echo "MongoDB 데이터 디렉토리 설정 중..."
mkdir -p /var/lib/mongodb
mkdir -p /var/log/mongodb
mkdir -p /var/run/mongodb
chown -R mongodb:mongodb /var/lib/mongodb
chown -R mongodb:mongodb /var/log/mongodb
chown -R mongodb:mongodb /var/run/mongodb

# MongoDB 설정 파일 백업 및 수정
echo "MongoDB 설정 파일 구성 중..."
cp /etc/mongod.conf /etc/mongod.conf.backup

# MongoDB 7.0 호환 설정 파일 생성 (단일 인스턴스용)
cat > /etc/mongod.conf << 'EOF'
# MongoDB 설정 파일 - Load Test 환경 (MongoDB 7.0)
# ${project_name}-${environment}

# 네트워크 인터페이스 설정
net:
  port: 27017
  bindIp: 0.0.0.0  # 모든 인터페이스에서 연결 허용 (보안 그룹으로 제한됨)

# 저장소 설정 (MongoDB 7.0 호환)
storage:
  dbPath: /var/lib/mongodb
  # journal.enabled 옵션은 MongoDB 7.0에서 제거됨 (기본적으로 활성화)
  wiredTiger:
    engineConfig:
      cacheSizeGB: 0.5  # t3.small에 맞춰 캐시 크기 조정

# 시스템 로그 설정
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log
  logRotate: rename

# 프로세스 관리 설정
processManagement:
  fork: true
  pidFilePath: /var/run/mongodb/mongod.pid
  timeZoneInfo: /usr/share/zoneinfo

# 보안 설정 (기본 설정 - 로드테스트용으로 인증 비활성화)
#security:
#  authorization: enabled
EOF

# MongoDB 7.0용 systemd 서비스 파일 생성
echo "MongoDB systemd 서비스 파일 생성 중..."
cat > /lib/systemd/system/mongod.service << 'EOF'
[Unit]
Description=MongoDB Database Server
Documentation=https://docs.mongodb.org/manual
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
User=mongodb
Group=mongodb
RuntimeDirectory=mongodb
RuntimeDirectoryMode=0755
PIDFile=/var/run/mongodb/mongod.pid
ExecStart=/usr/bin/mongod --config /etc/mongod.conf
ExecReload=/bin/kill -HUP $MAINPID
Restart=failed
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF

# systemd 데몬 리로드
echo "systemd 데몬 리로드 중..."
systemctl daemon-reload

# MongoDB 서비스 활성화 및 시작
echo "MongoDB 서비스 시작 중..."
systemctl enable mongod
systemctl start mongod

# 서비스 상태 확인
echo "MongoDB 서비스 상태 확인 중..."
sleep 5  # 서비스 시작 대기
for i in {1..10}; do
    if systemctl is-active --quiet mongod; then
        echo "MongoDB 서비스가 성공적으로 시작되었습니다."
        break
    fi
    echo "MongoDB 서비스 시작 대기 중... ($i/10)"
    sleep 2
done

# MongoDB 연결 테스트 (최대 30초 대기)
echo "MongoDB 연결 테스트 중..."
for i in {1..30}; do
    if mongosh --eval "db.runCommand({ping: 1})" >/dev/null 2>&1; then
        echo "MongoDB 연결 성공!"
        break
    fi
    echo "MongoDB 연결 대기 중... ($i/30)"
    sleep 1
done

# 연결 실패 시 디버깅 정보 출력
if ! mongosh --eval "db.runCommand({ping: 1})" >/dev/null 2>&1; then
    echo "MongoDB 연결 실패 - 디버깅 정보:"
    systemctl status mongod
    journalctl -u mongod --no-pager | tail -20
fi

# 초기 데이터베이스 생성 (최소한)
echo "기본 데이터베이스 생성 중..."
mongosh --eval "use loadtest; db.test.insertOne({init: true}); print('loadtest DB 생성 완료');"

# CloudWatch 에이전트 설치 및 설정 (최소한의 메모리 메트릭만 - 로드테스트 최적화)
echo "CloudWatch 에이전트 설치 중..."
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb
rm amazon-cloudwatch-agent.deb

echo "CloudWatch 에이전트 설정 중..."
mkdir -p /opt/aws/amazon-cloudwatch-agent/etc/
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent"
  },
  "metrics": {
    "namespace": "MongoDB/LoadTest",
    "metrics_collected": {
      "mem": {
        "measurement": [
          "mem_used_percent",
          "mem_cached"
        ],
        "metrics_collection_interval": 60
      }
    }
  }
}
EOF

# 메타데이터에서 현재 인스턴스의 자격증명 사용 (IAM 역할 없이)
echo "CloudWatch 에이전트 시작 중..."
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

# 서비스 활성화
systemctl enable amazon-cloudwatch-agent
systemctl restart amazon-cloudwatch-agent

echo "CloudWatch 에이전트 상태 확인..."
systemctl status amazon-cloudwatch-agent

# MongoDB 로그 로테이션 설정
echo "로그 로테이션 설정 중..."
cat > /etc/logrotate.d/mongodb << 'EOF'
/var/log/mongodb/*.log {
    daily
    missingok
    rotate 7
    compress
    notifempty
    create 644 mongodb mongodb
    postrotate
        /bin/kill -SIGUSR1 $(cat /var/run/mongodb/mongod.pid 2>/dev/null) 2>/dev/null || true
    endscript
}
EOF

# UFW 방화벽 설정 (Ubuntu 기본 방화벽)
echo "방화벽 설정 확인 중..."
if ufw status | grep -q "Status: active"; then
    echo "UFW가 활성화되어 있습니다. MongoDB 포트 허용 중..."
    ufw allow 27017/tcp
    ufw allow 22/tcp
fi

# 시스템 정보 출력
echo "=== 시스템 정보 ==="
echo "Hostname: $(hostname)"
echo "OS Version: $(lsb_release -d | cut -f2)"
echo "Private IP: $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
echo "Public IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "MongoDB Version: $(mongod --version | head -1)"
echo "MongoDB Status: $(systemctl is-active mongod)"

# MongoDB 간단 모니터링 스크립트 생성
echo "MongoDB 모니터링 스크립트 생성 중..."
cat > /usr/local/bin/mongodb-stats.sh << 'EOF'
#!/bin/bash
echo "=== MongoDB 상태 ==="
echo "시간: $(date)"
free -h | grep Mem
mongosh --quiet --eval "print('MongoDB 연결: ' + db.runCommand({ping:1}).ok)"
EOF
chmod +x /usr/local/bin/mongodb-stats.sh

# 간단 검증 스크립트 생성
echo "검증 스크립트 생성 중..."
cat > /usr/local/bin/verify-mongodb-setup.sh << 'EOF'
#!/bin/bash
echo "=== MongoDB 검증 ==="
echo "서비스: $(systemctl is-active mongod)"
if mongosh --eval "db.runCommand({ping: 1})" >/dev/null 2>&1; then
    echo "✅ MongoDB 연결 성공"
else
    echo "❌ MongoDB 연결 실패"
fi
echo "포트: $(netstat -ln | grep :27017 | wc -l)개 리스닝"
private_ip=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
echo "연결: mongodb://$private_ip:27017/loadtest"
EOF
chmod +x /usr/local/bin/verify-mongodb-setup.sh

# 설치 완료
echo "=== MongoDB 7.0 설치 완료: $(date) ==="
echo "MongoDB 서비스: $(systemctl is-active mongod)"
echo "검증 명령어: verify-mongodb-setup.sh"
sleep 3
/usr/local/bin/verify-mongodb-setup.sh 