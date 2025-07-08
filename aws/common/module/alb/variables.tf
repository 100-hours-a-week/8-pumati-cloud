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
# alb 설정
# ----------------------------------------------------------------------------------------------------------------------
# ALB 내부 여부
variable "internal" {
  description = "ALB를 내부용으로 설정할지 여부"
  type        = bool
}

# 서브넷
variable "public_subnet_ids" {
  description = "ALB가 배치될 퍼블릭 서브넷 ID"
  type        = list(string)
}

# 보안 그룹 ID 리스트
variable "security_group_ids" {
  description = "ALB에 연결할 보안 그룹 ID 리스트"
  type        = list(string)
}

# 삭제 방지 설정
variable "enable_deletion_protection" {
  description = "ALB에 삭제 방지 기능 활성화 여부"
  type        = bool
}

# ALB idle timeout
variable "idle_timeout" {
  description = "ALB idle timeout (초 단위)"
  type        = number
}

# ----------------------------------------------------------------------------------------------------------------------
# 네트워크 설정
# ----------------------------------------------------------------------------------------------------------------------
variable "vpc_id" {
  description = "VPC ID"
  type = string
}

# 여러 Target Group을 동적으로 정의
variable "target_groups" {
  description = "생성할 Target Group 목록 (key는 서비스 이름)"
  type = map(object({
    port        = number
    health_path = string
    matcher     = optional(string, "200")  # 기본값 200
  }))
}


