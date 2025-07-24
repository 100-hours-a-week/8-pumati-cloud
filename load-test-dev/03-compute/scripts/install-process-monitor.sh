#!/bin/bash
# 프로세스 모니터링 스크립트 설치 유틸리티

echo "=== 프로세스 모니터링 설치 시작 ==="

# 현재 디렉토리에서 process-monitor.sh 복사
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_SCRIPT="$SCRIPT_DIR/process-monitor.sh"
TARGET_SCRIPT="/usr/local/bin/process-monitor.sh"

if [ -f "$SOURCE_SCRIPT" ]; then
    echo "로컬 스크립트 발견, 복사 중..."
    cp "$SOURCE_SCRIPT" "$TARGET_SCRIPT"
else
    echo "로컬 스크립트 없음, 프로세스 모니터 스크립트 생성 중..."
    
    # 프로세스 모니터 스크립트 직접 생성
    cat > "$TARGET_SCRIPT" << 'MONITOR_EOF'
#!/bin/bash
# 프로세스 모니터링 및 Discord 알림 스크립트

DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/1397763151545761912/_kXALk1EBI84_DQLrL6aFo4ryV3ifLgkDfYAziS3Wd66FfWNIlOBh_0bl5ZMoirdnnKS"
PROJECT_NAME="pumati-load-test"
ENVIRONMENT="dev"
CHECK_INTERVAL=60
LOG_FILE="/var/log/process-monitor.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

send_discord_alert() {
    local title="$1"
    local description="$2"
    local color="$3"
    
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    INSTANCE_NAME=$(aws ec2 describe-tags --region ap-northeast-2 --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=Name" --query 'Tags[0].Value' --output text 2>/dev/null || echo "unknown")
    
    cat > /tmp/discord_payload.json << EOF
{
    "embeds": [
        {
            "title": "$title",
            "description": "$description",
            "color": $color,
            "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)",
            "fields": [
                {
                    "name": "🖥️ 인스턴스",
                    "value": "$INSTANCE_NAME ($INSTANCE_ID)",
                    "inline": true
                }
            ],
            "footer": {
                "text": "$PROJECT_NAME 프로세스 모니터"
            }
        }
    ]
}
EOF
    
    curl -H "Content-Type: application/json" -X POST -d @/tmp/discord_payload.json "$DISCORD_WEBHOOK_URL" 2>/dev/null
    rm -f /tmp/discord_payload.json
}

check_process() {
    local app_name="$1"
    local app_port="$2"
    
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

# 서비스 타입 감지 및 모니터링
if pm2 list 2>/dev/null | grep -q "backend"; then
    APP_NAME="backend-app"
elif pm2 list 2>/dev/null | grep -q "frontend"; then
    APP_NAME="frontend-app"
else
    log_message "PM2 애플리케이션을 찾을 수 없습니다"
    exit 1
fi

log_message "프로세스 모니터링 시작: $APP_NAME"
send_discord_alert "🔄 모니터링 시작" "$APP_NAME 프로세스 모니터링을 시작합니다." 65535

while true; do
    check_process "$APP_NAME" "3000"
    sleep "$CHECK_INTERVAL"
done
MONITOR_EOF
fi

# 실행 권한 부여
chmod +x "$TARGET_SCRIPT"

echo "프로세스 모니터 스크립트 설치 완료: $TARGET_SCRIPT"

# systemd 서비스 생성
echo "systemd 서비스 생성 중..."
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

# 필수 패키지 설치
echo "필수 패키지 설치 중..."
apt-get update -qq
apt-get install -y jq netcat curl

# 서비스 활성화
echo "서비스 활성화 중..."
systemctl daemon-reload
systemctl enable process-monitor.service
systemctl start process-monitor.service

# 상태 확인
sleep 2
if systemctl is-active --quiet process-monitor.service; then
    echo "✅ 프로세스 모니터링 서비스가 성공적으로 시작되었습니다!"
    systemctl status process-monitor.service --no-pager
else
    echo "❌ 프로세스 모니터링 서비스 시작 실패"
    systemctl status process-monitor.service --no-pager
fi

echo "=== 프로세스 모니터링 설치 완료 ===" 