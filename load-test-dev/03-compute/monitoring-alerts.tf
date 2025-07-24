# load-test-dev/03-compute/monitoring-alerts.tf
# 인스턴스 기반 Discord 웹훅 알림 시스템 (Lambda 없이)

# ===============================
# Discord 웹훅 변수
# ===============================

variable "discord_webhook_url" {
  description = "Discord 웹훅 URL"
  type        = string
  default     = "https://discord.com/api/webhooks/1397763151545761912/_kXALk1EBI84_DQLrL6aFo4ryV3ifLgkDfYAziS3Wd66FfWNIlOBh_0bl5ZMoirdnnKS"
}

variable "enable_discord_alerts" {
  description = "Discord 알림 활성화 여부"
  type        = bool
  default     = true
}

# ===============================
# 인스턴스 기반 모니터링 시스템
# ===============================
# Lambda 대신 각 인스턴스에서 직접 Discord 웹훅 호출
# CloudWatch 알람 없이 프로세스 모니터링만 사용

# ===============================
# 간단한 메모 (실제 모니터링은 인스턴스에서 진행)
# ===============================

# 모든 모니터링은 각 인스턴스의 process-monitor.sh 스크립트가 담당:
# 1. PM2 프로세스 상태 체크 (60초 간격)
# 2. 프로세스 다운 시 자동 재시작
# 3. 복구 성공/실패 여부를 Discord로 알림
# 4. 포트 접근성 확인
# 5. 인스턴스 시작/종료 알림

# 장점:
# - IAM 권한 불필요
# - Lambda 비용 없음  
# - 실시간 알림
# - 자동 복구 기능

# 모니터링 항목:
# ✅ 프로세스 상태 (PM2)
# ✅ 포트 접근성 (netcat)
# ✅ 자동 재시작
# ✅ Discord 알림

# 제외된 항목 (IAM 권한 필요):
# ❌ CloudWatch 알람
# ❌ ALB 타겟 건강성
# ❌ 5XX 에러율
# ❌ 응답 시간 모니터링
# ❌ ASG 이벤트 알림 