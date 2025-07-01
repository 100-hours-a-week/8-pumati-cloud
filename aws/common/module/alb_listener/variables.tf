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

variable "backend_target_group_arn" {
  description = "백엔드로 포워딩할 Target Group ARN"
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

variable "host_header" {
  description = "요청 허용할 호스트 헤더 (예: tebutebu.com)"
  type        = list(string)
}


variable "backend_path_patterns" {
  description = "/api/*, /oauth2/* 등 백엔드로 포워딩할 경로 목록"
  type        = list(string)
}

variable "frontend_path_patterns" {
  description = "프론트엔드로 포워딩할 경로 목록"
  type        = list(string)
}

variable "frontend_target_group_arn" {
  description = "프론트엔드로 포워딩할 Target Group ARN"
  type = string
}