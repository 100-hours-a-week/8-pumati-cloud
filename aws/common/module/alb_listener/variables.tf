variable "project_name" {
  description = "프로젝트 이름"
  type = string
}

variable "environment" {
  description = "환경 (예: dev, prod)"
  type = string
}

variable "service_name" {
  description = "서비스 이름(예: frontend, service, db)"
  type = string
}

variable "tags" {
  description = "공통 태그"
  type = map(string)
}

variable "load_balancer_arn" {
  description = "ALB ARN"
  type = string
}

variable "certificate_arn" {
  description = "ACM 인증서 ARN"
  type = string
}

variable "default_target_group_arn" {
  description = "기본 Target Group ARN"
  type = string
}

variable "api_target_group_arn" {
  description = "API 포워딩할 Target Group ARN"
  type = string
}

variable "enable_https" {
  description = "HTTPS 리스너 생성 여부"
  type = bool
  default = true
}

variable "enable_redirect" {
  description = "HTTP 리디렉션 리스너 생성 여부"
  type = bool
  default = true
}

