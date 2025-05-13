# ------------------------------------------------------------
# 프로젝트 변수
# ------------------------------------------------------------
variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "environment" {
  description = "환경 (예: dev, prod)"
  type        = string
}

variable "tags" {
  description = "리소스 태그"
  type        = map(string)
  default     = {}
}

# ------------------------------------------------------------
# 네트워크 변수
# ------------------------------------------------------------
variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
} 