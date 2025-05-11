# 프로젝트 관련 변수
variable "project_id" {
  description = "GCP 프로젝트 ID"
  type        = string
}

variable "region" {
  description = "GCP 리전"
  type        = string
}

# 시크릿 ID 변수
variable "secret_id" {
  description = "시크릿 ID"
  type        = string
}

# 시크릿 값 변수
variable "secret_value" {
  description = "시크릿 값"
  type        = string
  sensitive   = true
}

# 라벨
variable "labels" {
  description = "리소스에 적용할 라벨"
  type        = map(string)
}

# # 시크릿 접근자 목록
# variable "secret_accessors" {
#   description = "시크릿에 접근할 수 있는 멤버 목록"
#   type        = list(string)
#   default     = []
# }

