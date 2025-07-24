#!/bin/bash
# Redis 슬레이브 설치 및 설정 스크립트

set -e  # 에러 발생시 스크립트 중단

# 로그 파일 설정
LOG_FILE="/var/log/redis-slave-setup.log"
exec > >(tee -a $LOG_FILE)
exec 2>&1

echo "===== Redis 슬레이브 설치 시작 ====="
echo "시작 시간: $(date)"
echo "프로젝트: ${project_name}"
echo "환경: ${environment}"
echo "마스터 IP: ${master_ip}"

# 시스템 업데이트
echo "시스템 패키지 업데이트 중..."
apt-get update -y
apt-get upgrade -y

# 필수 패키지 설치
echo "필수 패키지 설치 중..."
apt-get install -y curl wget gnupg lsb-release build-essential

# Redis 설치
echo "Redis 설치 중..."
apt-get install -y redis-server

# Redis 설정 파일 백업
echo "Redis 설정 파일 백업 중..."
cp /etc/redis/redis.conf /etc/redis/redis.conf.backup

# Redis 슬레이브 설정
echo "Redis 슬레이브 설정 중..."
cat > /etc/redis/redis.conf << EOF
# Redis 슬레이브 설정 - 부하 테스트용

# 네트워크 설정
bind 0.0.0.0
port 6379
protected-mode no

# 메모리 설정 (t3.small: 2GB 메모리의 80% 사용)
maxmemory 1600mb
maxmemory-policy allkeys-lru

# 지속성 설정 (부하 테스트용으로 최소화)
save 900 1
save 300 10
save 60 10000

# AOF 비활성화 (성능 우선)
appendonly no

# 로그 설정
loglevel notice
logfile /var/log/redis/redis-server.log

# 타임아웃 설정
timeout 300
tcp-keepalive 300

# 클라이언트 연결 설정
maxclients 10000

# 슬로우 로그 설정
slowlog-log-slower-than 10000
slowlog-max-len 128

# 슬레이브 복제 설정
replicaof ${master_ip} 6379

# 읽기 전용 설정 (슬레이브는 읽기만 허용)
replica-read-only yes

# 마스터 연결 실패시 서비스 계속 제공
replica-serve-stale-data yes

# 복제 우선순위 (슬레이브가 마스터로 승격될 우선순위)
replica-priority 100

# 복제 설정
repl-diskless-sync yes
repl-diskless-sync-delay 5
EOF

# Redis 로그 디렉토리 생성
echo "Redis 로그 디렉토리 생성 중..."
mkdir -p /var/log/redis
chown redis:redis /var/log/redis

# 마스터 연결 대기
echo "마스터 서버 연결 대기 중..."
for i in {1..30}; do
    if nc -z ${master_ip} 6379; then
        echo "마스터 서버(${master_ip}:6379) 연결 확인!"
        break
    fi
    echo "마스터 서버 연결 재시도 중... ($i/30)"
    sleep 10
done

# Redis 서비스 활성화 및 시작
echo "Redis 서비스 시작 중..."
systemctl enable redis-server
systemctl restart redis-server

# Redis 서비스 상태 확인
echo "Redis 서비스 상태 확인 중..."
sleep 5
systemctl status redis-server

# Redis 연결 테스트
echo "Redis 연결 테스트 중..."
for i in {1..10}; do
    if redis-cli ping > /dev/null 2>&1; then
        echo "Redis 슬레이브 연결 성공!"
        break
    fi
    echo "Redis 연결 재시도 중... ($i/10)"
    sleep 2
done

# 복제 상태 확인
echo "Redis 복제 상태 확인 중..."
sleep 5
redis-cli info replication

# 마스터 연결 테스트
echo "마스터 서버 연결 테스트 중..."
redis-cli -h ${master_ip} ping && echo "마스터 서버 연결 성공!" || echo "마스터 서버 연결 실패!"

# CloudWatch Agent 설치 (모니터링용)
echo "CloudWatch Agent 설치 중..."
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb
rm amazon-cloudwatch-agent.deb

# CloudWatch Agent 설정
echo "CloudWatch Agent 설정 중..."
mkdir -p /opt/aws/amazon-cloudwatch-agent/etc/
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent"
  },
  "metrics": {
    "namespace": "Redis/LoadTest",
    "metrics_collected": {
      "mem": {
        "measurement": [
          "mem_used_percent",
          "mem_cached"
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          "used_percent"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/redis/redis-server.log",
            "log_group_name": "/aws/ec2/redis-slave",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
EOF

# CloudWatch Agent 시작
echo "CloudWatch Agent 시작 중..."
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s || echo "CloudWatch Agent 시작 실패 (IAM 권한 부족 가능)"

# Redis 모니터링 스크립트 생성
echo "Redis 모니터링 스크립트 생성 중..."
cat > /usr/local/bin/redis-monitor.sh << EOF
#!/bin/bash
echo "=== Redis 슬레이브 상태 ==="
echo "시간: \$(date)"
echo "메모리 사용량:"
free -h | grep Mem
echo ""
echo "Redis 정보:"
redis-cli info memory | grep used_memory_human
redis-cli info stats | grep total_commands_processed
echo ""
echo "복제 상태:"
redis-cli info replication
echo ""
echo "마스터 연결 상태:"
redis-cli -h ${master_ip} ping 2>/dev/null && echo "마스터 연결: OK" || echo "마스터 연결: FAIL"
echo ""
echo "로컬 Redis 연결 상태:"
redis-cli ping
EOF

chmod +x /usr/local/bin/redis-monitor.sh

# 복제 검증 스크립트 생성
echo "복제 검증 스크립트 생성 중..."
cat > /usr/local/bin/redis-replication-test.sh << EOF
#!/bin/bash
echo "=== Redis 복제 테스트 ==="

# 마스터에 테스트 데이터 입력
echo "마스터에 테스트 데이터 입력 중..."
TEST_KEY="replication_test_\$(date +%s)"
TEST_VALUE="test_value_\$(date)"

redis-cli -h ${master_ip} set "\$TEST_KEY" "\$TEST_VALUE"
echo "마스터에 입력: \$TEST_KEY = \$TEST_VALUE"

# 슬레이브에서 데이터 확인 (약간의 지연 후)
sleep 2
echo "슬레이브에서 데이터 확인 중..."
SLAVE_VALUE=\$(redis-cli get "\$TEST_KEY")

if [ "\$TEST_VALUE" = "\$SLAVE_VALUE" ]; then
    echo "✅ 복제 성공: 데이터가 정상적으로 복제되었습니다."
else
    echo "❌ 복제 실패: 데이터가 복제되지 않았습니다."
    echo "마스터 값: \$TEST_VALUE"
    echo "슬레이브 값: \$SLAVE_VALUE"
fi

# 테스트 데이터 정리
redis-cli -h ${master_ip} del "\$TEST_KEY"
echo "테스트 데이터 정리 완료"
EOF

chmod +x /usr/local/bin/redis-replication-test.sh

# 방화벽 설정 (UFW가 활성화된 경우)
echo "방화벽 설정 확인 중..."
if ufw status | grep -q "Status: active"; then
    echo "UFW 방화벽이 활성화되어 있습니다. Redis 포트 허용 중..."
    ufw allow 6379/tcp
    ufw allow 22/tcp
fi

# 시스템 정보 출력
echo "=== 시스템 정보 ==="
echo "호스트명: $(hostname)"
echo "Private IP: $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
echo "Public IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "Redis 버전: $(redis-cli --version)"
echo "Redis 상태: $(systemctl is-active redis-server)"
echo "마스터 IP: ${master_ip}"

# 최종 복제 상태 확인
echo ""
echo "=== 최종 복제 상태 확인 ==="
redis-cli info replication

echo "===== Redis 슬레이브 설치 완료 ====="
echo "완료 시간: $(date)"
echo ""
echo "연결 테스트 명령어:"
echo "redis-cli -h $(hostname -I | awk '{print $1}') ping"
echo ""
echo "모니터링 명령어:"
echo "redis-monitor.sh"
echo ""
echo "복제 테스트 명령어:"
echo "redis-replication-test.sh" 