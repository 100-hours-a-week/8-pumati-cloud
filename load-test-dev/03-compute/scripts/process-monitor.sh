#!/bin/bash
# 프로세스 모니터링 및 Discord 알림 스크립트
# 주기적으로 PM2 프로세스를 확인하고 문제 시 알림 전송

# 설정 변수
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/1397763151545761912/_kXALk1EBI84_DQLrL6aFo4ryV3ifLgkDfYAziS3Wd66FfWNIlOBh_0bl5ZMoirdnnKS"
PROJECT_NAME="pumati-load-test"
ENVIRONMENT="dev"
CHECK_INTERVAL=60  # 60초마다 체크
LOG_FILE="/var/log/process-monitor.log"

# 로그 함수
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

# Discord 알림 전송 함수
send_discord_alert() {
    local title="$1"
    local description="$2"
    local color="$3"
    local service_type="$4"
    
    # 인스턴스 정보 가져오기
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
    INSTANCE_NAME=$(aws ec2 describe-tags \
        --region ap-northeast-2 \
        --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=Name" \
        --query 'Tags[0].Value' --output text 2>/dev/null || echo "unknown")
    
    # 서비스 이모지 설정
    if [[ "$service_type" == "backend" ]]; then
        SERVICE_EMOJI="⚙️"
        SERVICE_NAME="Backend"
    else
        SERVICE_EMOJI="🖼️"
        SERVICE_NAME="Frontend"
    fi
    
    # Discord JSON 페이로드 생성
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
                    "name": "🖥️ 인스턴스 정보",
                    "value": "**이름**: \`$INSTANCE_NAME\`\n**ID**: \`$INSTANCE_ID\`\n**IP**: \`$PRIVATE_IP\`",
                    "inline": false
                },
                {
                    "name": "🌍 환경",
                    "value": "\`$ENVIRONMENT\`",
                    "inline": true
                },
                {
                    "name": "🔧 서비스",
                    "value": "$SERVICE_EMOJI $SERVICE_NAME",
                    "inline": true
                },
                {
                    "name": "📅 시간",
                    "value": "\`$(date '+%Y-%m-%d %H:%M:%S')\`",
                    "inline": true
                }
            ],
            "footer": {
                "text": "$PROJECT_NAME 프로세스 모니터링",
                "icon_url": "https://cdn.jsdelivr.net/gh/devicons/devicon/icons/nodejs/nodejs-original.svg"
            }
        }
    ],
    "username": "$PROJECT_NAME Process Monitor",
    "avatar_url": "https://cdn.jsdelivr.net/gh/devicons/devicon/icons/nodejs/nodejs-original.svg"
}
EOF
    
    # Discord 웹훅으로 전송
    curl -H "Content-Type: application/json" \
         -X POST \
         -d @/tmp/discord_payload.json \
         "$DISCORD_WEBHOOK_URL" \
         2>/dev/null
    
    # 임시 파일 정리
    rm -f /tmp/discord_payload.json
}

# PM2 프로세스 상태 확인 함수
check_pm2_processes() {
    local service_type="$1"
    local app_name="$2"
    local app_port="$3"
    
    log_message "PM2 프로세스 상태 확인 시작: $app_name"
    
    # PM2 프로세스 상태 확인
    pm2_status=$(pm2 jlist | jq -r ".[] | select(.name==\"$app_name\") | .pm2_env.status" 2>/dev/null)
    
    if [[ "$pm2_status" != "online" ]]; then
        log_message "❌ 프로세스 $app_name 상태 비정상: $pm2_status"
        
        # Discord 알림 전송
        send_discord_alert \
            "🚨 **프로세스 다운 감지!**" \
            "**$app_name** 프로세스가 정상 상태가 아닙니다.\n\n**상태**: \`$pm2_status\`\n\n**조치**: 프로세스 재시작을 시도합니다." \
            16711680 \
            "$service_type"
        
        # 프로세스 재시작 시도
        log_message "프로세스 재시작 시도: $app_name"
        pm2 restart "$app_name"
        
        # 재시작 후 잠시 대기
        sleep 10
        
        # 재시작 결과 확인
        new_status=$(pm2 jlist | jq -r ".[] | select(.name==\"$app_name\") | .pm2_env.status" 2>/dev/null)
        
        if [[ "$new_status" == "online" ]]; then
            log_message "✅ 프로세스 재시작 성공: $app_name"
            send_discord_alert \
                "✅ **프로세스 복구 성공**" \
                "**$app_name** 프로세스가 성공적으로 재시작되었습니다.\n\n**현재 상태**: \`$new_status\`" \
                65280 \
                "$service_type"
        else
            log_message "❌ 프로세스 재시작 실패: $app_name (상태: $new_status)"
            send_discord_alert \
                "💥 **프로세스 재시작 실패!**" \
                "**$app_name** 프로세스 재시작에 실패했습니다.\n\n**현재 상태**: \`$new_status\`\n\n**⚠️ 수동 개입이 필요할 수 있습니다.**" \
                16711680 \
                "$service_type"
        fi
    else
        log_message "✅ 프로세스 $app_name 정상 동작 중"
    fi
    
    # 포트 체크 (추가 검증)
    if ! nc -z localhost "$app_port" 2>/dev/null; then
        log_message "❌ 포트 $app_port 접근 불가 ($app_name)"
        send_discord_alert \
            "🔌 **포트 접근 실패**" \
            "**$app_name** 애플리케이션의 포트 **$app_port**에 접근할 수 없습니다.\n\n**조치**: 프로세스는 실행 중이지만 포트가 열려있지 않습니다." \
            16776960 \
            "$service_type"
    fi
}

# 메인 모니터링 루프
main_monitor_loop() {
    log_message "프로세스 모니터링 시작"
    
    # 서비스 타입 자동 감지
    if pm2 list | grep -q "backend"; then
        SERVICE_TYPE="backend"
        APP_NAME="backend-app"
        APP_PORT="3000"
    elif pm2 list | grep -q "frontend"; then
        SERVICE_TYPE="frontend"
        APP_NAME="frontend-app"
        APP_PORT="3000"
    else
        log_message "❌ PM2에서 인식 가능한 애플리케이션을 찾을 수 없습니다"
        exit 1
    fi
    
    log_message "감지된 서비스: $SERVICE_TYPE ($APP_NAME)"
    
    # 시작 알림 전송
    send_discord_alert \
        "🔄 **프로세스 모니터링 시작**" \
        "**$APP_NAME** 프로세스 모니터링을 시작합니다.\n\n**체크 주기**: ${CHECK_INTERVAL}초" \
        65535 \
        "$SERVICE_TYPE"
    
    # 무한 루프로 모니터링
    while true; do
        check_pm2_processes "$SERVICE_TYPE" "$APP_NAME" "$APP_PORT"
        sleep "$CHECK_INTERVAL"
    done
}

# 스크립트 종료 시 정리
cleanup() {
    log_message "프로세스 모니터링 종료"
    send_discord_alert \
        "🛑 **프로세스 모니터링 종료**" \
        "프로세스 모니터링이 종료되었습니다." \
        16776960 \
        "${SERVICE_TYPE:-unknown}"
    exit 0
}

# 시그널 핸들링 설정
trap cleanup SIGTERM SIGINT

# 필수 도구 확인
if ! command -v pm2 &> /dev/null; then
    log_message "❌ PM2가 설치되어 있지 않습니다"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    log_message "jq 설치 중..."
    apt-get update && apt-get install -y jq
fi

if ! command -v nc &> /dev/null; then
    log_message "netcat 설치 중..."
    apt-get update && apt-get install -y netcat
fi

# 메인 함수 실행
main_monitor_loop 