#!/bin/bash
# 시스템 상태 모니터링 및 Discord 알림 스크립트
# 인스턴스 시작/종료, 높은 CPU/메모리 사용률 알림

DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/1397763151545761912/_kXALk1EBI84_DQLrL6aFo4ryV3ifLgkDfYAziS3Wd66FfWNIlOBh_0bl5ZMoirdnnKS"
PROJECT_NAME="pumati-load-test"
ENVIRONMENT="dev"
LOG_FILE="/var/log/system-monitor.log"

# CPU/메모리 임계값 설정
CPU_THRESHOLD=80    # 80% 이상
MEMORY_THRESHOLD=85 # 85% 이상
DISK_THRESHOLD=90   # 90% 이상

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

# Discord 알림 전송 함수
send_system_alert() {
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
    elif [[ "$service_type" == "frontend" ]]; then
        SERVICE_EMOJI="🖼️"
        SERVICE_NAME="Frontend"
    else
        SERVICE_EMOJI="🖥️"
        SERVICE_NAME="System"
    fi
    
    # 시스템 정보 수집
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')
    MEMORY_USAGE=$(free | grep Mem | awk '{printf("%.1f"), ($3/$2) * 100.0}')
    DISK_USAGE=$(df -h / | awk 'NR==2{printf "%s", $5}' | sed 's/%//')
    LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}')
    
    # Discord JSON 페이로드 생성
    cat > /tmp/system_alert.json << EOF
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
                    "name": "💻 시스템 상태",
                    "value": "**CPU**: ${CPU_USAGE}%\n**메모리**: ${MEMORY_USAGE}%\n**디스크**: ${DISK_USAGE}%",
                    "inline": true
                },
                {
                    "name": "🔧 서비스",
                    "value": "$SERVICE_EMOJI $SERVICE_NAME",
                    "inline": true
                },
                {
                    "name": "⚖️ 시스템 부하",
                    "value": "\`$LOAD_AVG\`",
                    "inline": true
                },
                {
                    "name": "🌍 환경",
                    "value": "\`$ENVIRONMENT\`",
                    "inline": true
                },
                {
                    "name": "📅 시간",
                    "value": "\`$(date '+%Y-%m-%d %H:%M:%S')\`",
                    "inline": true
                }
            ],
            "footer": {
                "text": "$PROJECT_NAME 시스템 모니터링",
                "icon_url": "https://cdn.jsdelivr.net/gh/devicons/devicon/icons/ubuntu/ubuntu-plain.svg"
            }
        }
    ],
    "username": "$PROJECT_NAME System Monitor",
    "avatar_url": "https://cdn.jsdelivr.net/gh/devicons/devicon/icons/ubuntu/ubuntu-plain.svg"
}
EOF
    
    # Discord 웹훅으로 전송
    curl -H "Content-Type: application/json" \
         -X POST \
         -d @/tmp/system_alert.json \
         "$DISCORD_WEBHOOK_URL" \
         2>/dev/null
    
    # 임시 파일 정리
    rm -f /tmp/system_alert.json
}

# 인스턴스 시작 알림
send_startup_notification() {
    local service_type
    
    # 서비스 타입 자동 감지
    if pm2 list 2>/dev/null | grep -q "backend"; then
        service_type="backend"
    elif pm2 list 2>/dev/null | grep -q "frontend"; then
        service_type="frontend"
    else
        service_type="system"
    fi
    
    log_message "인스턴스 시작 알림 전송: $service_type"
    
    send_system_alert \
        "🚀 **인스턴스 시작 완료**" \
        "새로운 인스턴스가 성공적으로 시작되었습니다.\n\n**시작 시간**: $(uptime -s)" \
        65280 \
        "$service_type"
}

# 리소스 사용률 체크
check_resource_usage() {
    # CPU 사용률 체크
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}' | awk '{print int($1)}')
    
    # 메모리 사용률 체크
    MEMORY_USAGE=$(free | grep Mem | awk '{printf("%.0f"), ($3/$2) * 100.0}')
    
    # 디스크 사용률 체크
    DISK_USAGE=$(df -h / | awk 'NR==2{printf "%s", $5}' | sed 's/%//')
    
    # CPU 임계값 초과 체크
    if [ "$CPU_USAGE" -gt "$CPU_THRESHOLD" ]; then
        log_message "높은 CPU 사용률 감지: ${CPU_USAGE}%"
        send_system_alert \
            "⚠️ **높은 CPU 사용률 경고**" \
            "CPU 사용률이 임계값을 초과했습니다.\n\n**현재 사용률**: ${CPU_USAGE}%\n**임계값**: ${CPU_THRESHOLD}%" \
            16776960 \
            "system"
    fi
    
    # 메모리 임계값 초과 체크
    if [ "$MEMORY_USAGE" -gt "$MEMORY_THRESHOLD" ]; then
        log_message "높은 메모리 사용률 감지: ${MEMORY_USAGE}%"
        send_system_alert \
            "⚠️ **높은 메모리 사용률 경고**" \
            "메모리 사용률이 임계값을 초과했습니다.\n\n**현재 사용률**: ${MEMORY_USAGE}%\n**임계값**: ${MEMORY_THRESHOLD}%" \
            16776960 \
            "system"
    fi
    
    # 디스크 임계값 초과 체크
    if [ "$DISK_USAGE" -gt "$DISK_THRESHOLD" ]; then
        log_message "높은 디스크 사용률 감지: ${DISK_USAGE}%"
        send_system_alert \
            "🚨 **디스크 공간 부족 경고**" \
            "디스크 사용률이 임계값을 초과했습니다.\n\n**현재 사용률**: ${DISK_USAGE}%\n**임계값**: ${DISK_THRESHOLD}%" \
            16711680 \
            "system"
    fi
}

# ALB Health Check 모니터링 (간접적)
check_alb_connectivity() {
    local app_port
    
    # 서비스 타입별 포트 확인
    if pm2 list 2>/dev/null | grep -q "backend"; then
        app_port="3000"
        service_type="backend"
    elif pm2 list 2>/dev/null | grep -q "frontend"; then
        app_port="3000"
        service_type="frontend"
    else
        return
    fi
    
    # 포트 접근성 확인 (3번 연속 실패시 알림)
    FAILED_COUNT=0
    for i in {1..3}; do
        if ! nc -z localhost "$app_port" 2>/dev/null; then
            FAILED_COUNT=$((FAILED_COUNT + 1))
        fi
        sleep 2
    done
    
    if [ "$FAILED_COUNT" -eq 3 ]; then
        log_message "ALB 연결성 문제 감지: 포트 $app_port 접근 불가"
        send_system_alert \
            "🔌 **ALB 연결성 문제 감지**" \
            "애플리케이션 포트에 접근할 수 없습니다.\n\n**포트**: $app_port\n**상태**: 3번 연속 실패\n\n이는 ALB Health Check 실패로 이어질 수 있습니다." \
            16711680 \
            "$service_type"
    fi
}

# 메인 실행 부분
case "${1:-startup}" in
    "startup")
        # 인스턴스 시작 알림
        sleep 30  # 시스템 안정화 대기
        send_startup_notification
        ;;
    "monitor")
        # 지속적인 모니터링
        log_message "시스템 모니터링 시작"
        while true; do
            check_resource_usage
            check_alb_connectivity
            sleep 300  # 5분 간격으로 체크
        done
        ;;
    "check")
        # 일회성 체크
        check_resource_usage
        check_alb_connectivity
        ;;
    *)
        echo "사용법: $0 {startup|monitor|check}"
        echo "  startup: 인스턴스 시작 알림"
        echo "  monitor: 지속적인 시스템 모니터링"
        echo "  check: 일회성 상태 체크"
        exit 1
        ;;
esac 