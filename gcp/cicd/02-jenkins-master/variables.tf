# Jenkins 관리자 계정 변수
variable "jenkins_admin_username" {
  description = "Jenkins 관리자 계정 사용자명"
  type        = string
  sensitive   = true
}

variable "jenkins_admin_password" {
  description = "Jenkins 관리자 계정 비밀번호"
  type        = string
  sensitive   = true
} 