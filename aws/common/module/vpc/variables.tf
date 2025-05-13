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
  description = "추가 태그"
  type        = map(string)
  default     = {}
}
# ------------------------------------------------------------
# VPC 변수
# ------------------------------------------------------------
variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
}

variable "vpc_az" {
  description = "가용영역"
  type        = string
}
# ------------------------------------------------------------
# 퍼블릭 서브넷 변수
# ------------------------------------------------------------  
variable "vpc_public_subnets_a_cidr" {
  description = "퍼블릭 서브넷 CIDR 블록"
  type        = string
}
