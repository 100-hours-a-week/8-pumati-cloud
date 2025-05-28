# modules/vpc/variables.tf
variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "environment" {
  description = "환경 (예: dev, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
}

variable "az" {
  description = "사용할 가용 영역 (예: ap-northeast-2a)"
  type        = string
}

variable "public_subnet_cidr" {
  description = "퍼블릭 서브넷 CIDR"
  type        = string
}

variable "service_subnet_cidr" {
  description = "서비스 서브넷 CIDR"
  type        = string
}

variable "db_subnet_cidr" {
  description = "DB 서브넷 CIDR"
  type        = string
}

variable "enable_service_subnet" {
  description = "서비스 서브넷 생성 여부"
  type        = bool
  default     = false
}

variable "enable_db_subnet" {
  description = "DB 서브넷 생성 여부"
  type        = bool
  default     = false
}
variable "map_public_ip_on_launch" {
  description = "퍼블릭 서브넷에 퍼블릭 IP 할당 여부"
  type        = bool
  default     = true
}

variable "tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}