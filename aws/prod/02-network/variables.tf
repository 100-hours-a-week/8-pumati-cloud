# ------------------------------------------------------------
# VPC 변수
# ------------------------------------------------------------
variable "vpc_az" {
  type        = string
  description = "가용영역"
  default     = "ap-northeast-2a"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR 블록"
  default     = "10.2.0.0/16"
}

variable "vpc_public_subnets_a_cidr" {
  type        = string
  description = "퍼블릭 서브넷 CIDR 블록"
  default     = "10.2.0.0/24"
} 