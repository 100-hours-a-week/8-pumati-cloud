variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "environment" {
  description = "환경 이름 (예: dev, prod)"
  type        = string
}

variable "service_name" {
  description = "서비스 이름 (예: frontend, backend, budget)"
  type        = string
}

variable "tags" {
  description = "리소스에 추가할 공통 태그"
  type        = map(string)
  default     = {}
}

# ----------------------------------------------------------------------------------------------------------------------
# Budget 설정
# ----------------------------------------------------------------------------------------------------------------------
variable "budget_limit" {
  description = "월 예산 한도 (USD)"
  type        = string
}

variable "start_time" {
  description = "예산 시작 시간 (예: 2025-07-01_00:00)"
  type        = string
}

variable "end_time" {
  description = "예산 종료 시간 (예: 2025-07-31_23:59)"
  type        = string
}

# ----------------------------------------------------------------------------------------------------------------------
# 알림 조건 및 수신자 설정
# ----------------------------------------------------------------------------------------------------------------------
variable "notification_settings" {
  description = "알림 조건 목록"
  # 알림 조건 목록 (각 조건에 대해 SNS 사용 여부 포함):
  # threshold: 임계값 (숫자)
  # threshold_type: "PERCENTAGE" 또는 "ABSOLUTE_VALUE"
  # notification_type: "ACTUAL" 또는 "FORECASTED"
  # enable_sns: SNS 알림 여부
  type = list(object({
    threshold          = number
    threshold_type     = string
    notification_type  = string
    enable_sns         = bool
  }))
}

variable "alert_email" {
  description = "알림을 받을 이메일 주소(들)"
  type        = list(string)
}

variable "sns_topic_arn" {
  description = "알림을 보낼 SNS Topic ARN (선택사항)"
  type        = string
  default     = null
}
