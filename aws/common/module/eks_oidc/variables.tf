variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "environment" {
  description = "환경 이름 (예: dev, prod)"
  type        = string
}

variable "service_name" {
  description = "서비스 이름"
  type        = string
}

variable "tags" {
  description = "리소스에 추가할 태그"
  type        = map(string)
  default     = {}
}

#------------------------------------------------------------------------------
# EKS OIDC 설정
#------------------------------------------------------------------------------
variable "oidc_url" {
  description = "OIDC URL"
  type        = string
}