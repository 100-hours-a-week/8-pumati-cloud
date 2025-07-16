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
# --------------------------------------------------------------------------------------
variable "instance_profile_enabled" {
  description = "EC2 등에서 사용 시 true로 설정, Firehose 등은 false"
  type        = bool
  default     = false
}
variable "enable_inline_policy" {
  description = "인라인 정책을 적용할지 여부 (true 시 적용)"
  type        = bool
  default     = false
}

variable "enable_managed_policy" {
  description = "관리형 정책을 연결할지 여부 (true 시 적용)"
  type        = bool
  default     = false
}

variable "inline_policy_json" {
  description = "IAM Role에 추가할 인라인 정책의 JSON"
  type        = string
  default     = ""
}

variable "managed_policy_arns" {
  description = "연결할 AWS 관리형 정책 ARN 목록"
  type        = list(string)
  default     = []
}

variable "assume_role_service" {
  description = "Assume role 대상 서비스 (예: ec2.amazonaws.com, firehose.amazonaws.com)"
  type        = string
}
