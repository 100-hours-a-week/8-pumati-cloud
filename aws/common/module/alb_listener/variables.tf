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

# ----------------------------------------------------------------------------------------------------------------------
# 리스너 설정
# ----------------------------------------------------------------------------------------------------------------------
variable "load_balancer_arn" {
  description = "ALB ARN"
  type = string
}

variable "certificate_arn" {
  description = "ACM 인증서 ARN"
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

variable "listener_rules" {
  description = "리스너 룰 설정: key는 룰 이름, value는 조건 및 타겟 그룹 정보"
  type = map(object({
    priority         = number
    host_headers     = list(string)
    path_patterns    = list(string)
    target_group_arn = string
  }))
}
