#!/bin/bash
# 프론트엔드 서버 설정 스크립트 (커스텀 AMI 사용)
# Project: ${project_name}
# Environment: ${environment}

# 로그 설정
LOG_FILE="/var/log/frontend-setup.log"
exec > >(tee -a $LOG_FILE)
exec 2>&1

echo "=== 프론트엔드 서버 설정 시작: $(date) ==="

# 인스턴스 정보 가져오기
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

# IP 기반 인스턴스 이름 생성 (IAM 권한 불필요)
# Private IP의 마지막 두 옥테트를 사용하여 고유한 이름 생성
IP_SUFFIX=$(echo $PRIVATE_IP | awk -F. '{print $3"-"$4}')

# 인스턴스 이름을 frontend-{IP_끝자리}로 설정
NEW_NAME="frontend-$IP_SUFFIX"

# EC2 인스턴스에 새 이름 태그 적용
aws ec2 create-tags \
  --region ap-northeast-2 \
  --resources $INSTANCE_ID \
  --tags Key=Name,Value=$NEW_NAME

echo "인스턴스 이름을 '$NEW_NAME'으로 설정했습니다 (Instance ID: $INSTANCE_ID)"

# 환경 변수 설정
export PROJECT_NAME="${project_name}"
export ENVIRONMENT="${environment}"
export APP_PORT="${app_port}"
export LOG_GROUP_NAME="${log_group_name}"
export BACKEND_API_URL="${backend_api_url}"
export INSTANCE_NAME="$NEW_NAME"

# CloudWatch Agent 설정 파일 생성
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
    "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "cwagent"
    },
    "metrics": {
        "namespace": "LoadTest/Frontend",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
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
            },
            "diskio": {
                "measurement": [
                    "io_time",
                    "read_bytes",
                    "write_bytes",
                    "reads",
                    "writes"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent",
                    "mem_total",
                    "mem_used"
                ],
                "metrics_collection_interval": 60
            },
            "netstat": {
                "measurement": [
                    "tcp_established",
                    "tcp_time_wait"
                ],
                "metrics_collection_interval": 60
            }
        }
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/frontend-app/*.log",
                        "log_group_name": "${log_group_name}",
                        "log_stream_name": "{instance_id}-app",
                        "timezone": "UTC"
                    },
                    {
                        "file_path": "/var/log/frontend-setup.log",
                        "log_group_name": "${log_group_name}",
                        "log_stream_name": "{instance_id}-setup",
                        "timezone": "UTC"
                    }
                ]
            }
        }
    }
}
EOF

# CloudWatch Agent 시작 (IAM 역할 없이)
echo "CloudWatch Agent 시작 중... (제한된 권한으로 동작)"
# IAM 역할이 없으므로 CloudWatch Agent는 제한된 기능으로만 동작
# 메트릭 수집은 시도하지만 로그 전송은 실패할 수 있음
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s || echo "CloudWatch Agent 시작 실패 (IAM 권한 부족)"

# 애플리케이션 환경변수 파일 생성 (커스텀 AMI에서 사용)
mkdir -p /opt/app
cat > /opt/app/.env.local << EOF
NODE_ENV=production
PORT=${app_port}
NEXT_PUBLIC_API_URL=${backend_api_url}
PROJECT_NAME=${project_name}
ENVIRONMENT=${environment}
AWS_REGION=ap-northeast-2
EOF

# PM2 프로세스 재시작 (커스텀 AMI에 이미 설정되어 있다고 가정)
echo "프론트엔드 애플리케이션 시작 중..."
cd /opt/app

# Next.js 빌드 재실행 (환경변수 변경시)
if [ -f "package.json" ]; then
    echo "Next.js 빌드 중..."
    npm run build
fi

# PM2로 애플리케이션 시작/재시작
pm2 restart frontend-app || pm2 start ecosystem.config.js --name frontend-app

# PM2 startup 설정
pm2 startup
pm2 save

# 프로세스 모니터링 설치 (간단 버전)
echo "프로세스 모니터링 설정 중..."

# 프로세스 모니터 스크립트 생성 및 설치 (동일한 스크립트)
cat > /usr/local/bin/process-monitor.sh << 'MONITOR_EOF'
#!/bin/bash
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/1397763151545761912/_kXALk1EBI84_DQLrL6aFo4ryV3ifLgkDfYAziS3Wd66FfWNIlOBh_0bl5ZMoirdnnKS"
PROJECT_NAME="pumati-load-test"
ENVIRONMENT="dev"
CHECK_INTERVAL=30  # 30초로 단축 (부하 증가 패턴에 맞춰)
LOG_FILE="/var/log/process-monitor.log"

log_message() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE; }

send_discord_alert() {
    local title="$1"; local description="$2"; local color="$3"
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    INSTANCE_NAME=$(aws ec2 describe-tags --region ap-northeast-2 --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=Name" --query 'Tags[0].Value' --output text 2>/dev/null || echo "unknown")
    
    cat > /tmp/discord_payload.json << EOF
{"embeds":[{"title":"$title","description":"$description","color":$color,"timestamp":"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)","fields":[{"name":"🖥️ 인스턴스","value":"$INSTANCE_NAME ($INSTANCE_ID)","inline":true}],"footer":{"text":"$PROJECT_NAME 프로세스 모니터"}}]}
EOF
    curl -H "Content-Type: application/json" -X POST -d @/tmp/discord_payload.json "$DISCORD_WEBHOOK_URL" 2>/dev/null
    rm -f /tmp/discord_payload.json
}

check_process() {
    local app_name="$1"
    pm2_status=$(pm2 jlist 2>/dev/null | jq -r ".[] | select(.name==\"$app_name\") | .pm2_env.status" 2>/dev/null)
    
    if [[ "$pm2_status" != "online" ]]; then
        log_message "❌ 프로세스 $app_name 비정상: $pm2_status"
        send_discord_alert "🚨 프로세스 다운!" "$app_name 프로세스가 다운되었습니다. 재시작을 시도합니다." 16711680
        
        pm2 restart "$app_name"
        sleep 10
        
        new_status=$(pm2 jlist 2>/dev/null | jq -r ".[] | select(.name==\"$app_name\") | .pm2_env.status" 2>/dev/null)
        if [[ "$new_status" == "online" ]]; then
            log_message "✅ 프로세스 재시작 성공: $app_name"
            send_discord_alert "✅ 프로세스 복구!" "$app_name 프로세스가 성공적으로 복구되었습니다." 65280
        else
            log_message "❌ 프로세스 재시작 실패: $app_name"
            send_discord_alert "💥 복구 실패!" "$app_name 프로세스 복구에 실패했습니다. 수동 개입이 필요합니다." 16711680
        fi
    fi
}

# 서비스 타입 감지
if pm2 list 2>/dev/null | grep -q "backend"; then APP_NAME="backend-app"
elif pm2 list 2>/dev/null | grep -q "frontend"; then APP_NAME="frontend-app"
else log_message "PM2 애플리케이션을 찾을 수 없습니다"; exit 1; fi

log_message "프로세스 모니터링 시작: $APP_NAME"
# 시작 알림 제거 - 문제 발생시만 알림

while true; do check_process "$APP_NAME"; sleep "$CHECK_INTERVAL"; done
MONITOR_EOF

chmod +x /usr/local/bin/process-monitor.sh

# systemd 서비스 생성
cat > /etc/systemd/system/process-monitor.service << 'SERVICE_EOF'
[Unit]
Description=Process Monitor for PM2 Applications
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/process-monitor.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# 필수 패키지 설치 및 서비스 시작
apt-get update -qq && apt-get install -y jq netcat
systemctl daemon-reload
systemctl enable process-monitor.service
systemctl start process-monitor.service

echo "✅ 프로세스 모니터링 설정 완료!"

# 시스템 모니터링 스크립트 설치 (프론트엔드용)
echo "시스템 모니터링 설정 중..."
cat > /usr/local/bin/system-monitor.sh << 'SYSTEM_EOF'
#!/bin/bash
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/1397763151545761912/_kXALk1EBI84_DQLrL6aFo4ryV3ifLgkDfYAziS3Wd66FfWNIlOBh_0bl5ZMoirdnnKS"
PROJECT_NAME="pumati-load-test"
ENVIRONMENT="dev"
CPU_THRESHOLD=80
MEMORY_THRESHOLD=85
DISK_THRESHOLD=90

send_system_alert() {
    local title="$1"; local description="$2"; local color="$3"; local service_type="$4"
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    INSTANCE_NAME=$(aws ec2 describe-tags --region ap-northeast-2 --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=Name" --query 'Tags[0].Value' --output text 2>/dev/null || echo "unknown")
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')
    MEMORY_USAGE=$(free | grep Mem | awk '{printf("%.1f"), ($3/$2) * 100.0}')
    
    cat > /tmp/system_alert.json << EOF
{"embeds":[{"title":"$title","description":"$description","color":$color,"timestamp":"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)","fields":[{"name":"🖥️ 인스턴스","value":"$INSTANCE_NAME ($INSTANCE_ID)","inline":false},{"name":"💻 시스템","value":"CPU: $${CPU_USAGE}% | 메모리: $${MEMORY_USAGE}%","inline":true}],"footer":{"text":"$PROJECT_NAME 시스템 모니터"}}]}
EOF
    curl -H "Content-Type: application/json" -X POST -d @/tmp/system_alert.json "$DISCORD_WEBHOOK_URL" 2>/dev/null
    rm -f /tmp/system_alert.json
}

check_resources() {
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}' | awk '{print int($1)}')
    MEMORY_USAGE=$(free | grep Mem | awk '{printf("%.0f"), ($3/$2) * 100.0}')
    DISK_USAGE=$(df -h / | awk 'NR==2{printf "%s", $5}' | sed 's/%//')
    
    [ "$CPU_USAGE" -gt "$CPU_THRESHOLD" ] && send_system_alert "⚠️ 높은 CPU 사용률" "CPU: $${CPU_USAGE}% (임계값: $${CPU_THRESHOLD}%)" 16776960 "frontend"
    [ "$MEMORY_USAGE" -gt "$MEMORY_THRESHOLD" ] && send_system_alert "⚠️ 높은 메모리 사용률" "메모리: $${MEMORY_USAGE}% (임계값: $${MEMORY_THRESHOLD}%)" 16776960 "frontend"
    [ "$DISK_USAGE" -gt "$DISK_THRESHOLD" ] && send_system_alert "🚨 디스크 공간 부족" "디스크: $${DISK_USAGE}% (임계값: $${DISK_THRESHOLD}%)" 16711680 "frontend"
}

case "$${1:-monitor}" in
    "monitor") while true; do check_resources; sleep 120; done ;;  # 2분 간격으로 단축
    "check") check_resources ;;
esac
SYSTEM_EOF

chmod +x /usr/local/bin/system-monitor.sh

# 시스템 모니터링 서비스 생성
cat > /etc/systemd/system/system-monitor.service << 'SYSTEM_SERVICE_EOF'
[Unit]
Description=System Resource Monitor
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/system-monitor.sh monitor
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
SYSTEM_SERVICE_EOF

systemctl enable system-monitor.service
systemctl start system-monitor.service

# 인스턴스 시작 알림 제거 (문제 발생시만 알림)

# Health Check 엔드포인트 확인
echo "Health Check 대기 중..."
for i in {1..30}; do
    if curl -f http://localhost:${app_port}/ >/dev/null 2>&1; then
        echo "프론트엔드 애플리케이션 정상 시작 확인!"
        break
    fi
    echo "Health Check 대기 중... ($i/30)"
    sleep 10
done

# Nginx 설정 업데이트 (만약 Nginx가 있다면)
if command -v nginx &> /dev/null; then
    echo "Nginx 설정 업데이트 중..."
    
    # 백엔드 API 프록시 설정 업데이트
    cat > /etc/nginx/conf.d/api-proxy.conf << EOF
location /api/ {
    proxy_pass ${backend_api_url}/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_cache_bypass \$http_upgrade;
}
EOF
    
    # Nginx 설정 테스트 및 재로드
    nginx -t && nginx -s reload
fi

# 시스템 정보 출력
echo "=== 시스템 정보 ==="
echo "Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
echo "Private IP: $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
echo "App Port: ${app_port}"
echo "Backend API URL: ${backend_api_url}"
echo "PM2 Status:"
pm2 status

# Nginx 상태 (있다면)
if command -v nginx &> /dev/null; then
    echo "Nginx Status:"
    systemctl status nginx --no-pager
fi

echo "=== 프론트엔드 서버 설정 완료: $(date) ===" 