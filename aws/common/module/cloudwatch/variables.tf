variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "environment" {
  description = "환경 이름 (예: dev, prod)"
  type        = string
}

variable "service_name" {
  description = "서비스 이름 (예: frontend, backend, management)"
  type        = string
}

variable "tags" {
  description = "리소스에 추가할 태그"
  type        = map(string)
  default     = {}
}
# ----------------------------------------------------------------------------------------------------------------------
# CloudWatch 로그 그룹 설정
# ----------------------------------------------------------------------------------------------------------------------
variable "log_group_name" {
  description = "CloudWatch 로그 그룹 이름 (예: /aws/lambda/function-name)"
  type        = string
}

variable "retention_in_days" {
  description = "로그 보존 기간 (일)"
  type        = number
  default     = 14
}

variable "kms_key_id" {
  description = "로그 암호화에 사용할 KMS 키 ID (선택사항)"
  type        = string
  default     = null
}
