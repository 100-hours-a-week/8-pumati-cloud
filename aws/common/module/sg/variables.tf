variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "environment" {
  description = "환경 (예: dev, prod)"
  type        = string
}

variable "instance_name" {
  description = "인스턴스 구분 이름 (예: frontend, backend, jenkins)"
  type        = string
}

variable "name" {
  description = "보안 그룹 이름"
  type        = string
}

variable "description" {
  description = "보안 그룹 설명"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "tags" {
  description = "공통 태그"
  type        = map(string)
}

variable "ingress_rules" {
  description = "인바운드 규칙 리스트"
  type = list(object({
    from_port       = number
    to_port         = number
    protocol        = string
    cidr_blocks     = optional(list(string))
    security_groups = optional(list(string))
    description     = optional(string)
  }))
}
