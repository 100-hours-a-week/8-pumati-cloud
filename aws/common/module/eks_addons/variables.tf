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

# ----------------------------------------------------------------------------------------------------------------------
# EKS Add-on 설정
# ----------------------------------------------------------------------------------------------------------------------
variable "cluster_name" {
  description = "EKS 클러스터 이름"
  type        = string
}
variable "addon_name" {
  description = "Add-on 이름"
  type        = string
}
variable "addon_version" {
  description = "Add-on 버전"
  type    = string
  default = null
}
variable "service_account_role_arn" {
  description = "Service Account Role ARN"
  type    = string
  default = null
}
variable "resolve_conflicts_on_create" {
  description = "Create 시 충돌 해결 방법"
  type        = string
  default     = "OVERWRITE"
}
variable "resolve_conflicts_on_update" {
  description = "Update 시 충돌 해결 방법"
  type        = string
  default     = "OVERWRITE"
}

variable "purpose" {
  type    = string
  default = ""
}
variable "component" {
  type    = string
  default = ""
}
