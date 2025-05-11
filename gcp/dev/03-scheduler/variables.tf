variable "project_id" {
  description = "프로젝트 ID"
  type        = string
}

variable "mig_name" {
  description = "관리형 인스턴스 그룹 이름"
  type        = string
}

variable "mig_region" {
  description = "관리형 인스턴스 그룹 리전"
  type        = string
}

variable "terraform_service_account" {
  description = "테라폼 서비스 계정 이메일"
  type        = string
}
