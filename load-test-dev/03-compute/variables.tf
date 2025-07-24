# load-test-dev/03-compute/variables.tf
# Compute 리소스 설정 변수 - 백엔드 전용

# 백엔드 인스턴스 설정 (오토 힐링 전용)
variable "backend_instance_count" {
  description = "백엔드 인스턴스 수 (고정 5개, 오토 힐링만 활용)"
  type        = number
  default     = 5
}

# 인스턴스 설정
variable "instance_type" {
  description = "EC2 인스턴스 타입"
  type        = string
  default     = "t3.small"
}

variable "custom_backend_ami" {
  description = "백엔드용 커스텀 AMI ID (CI/CD로 생성)"
  type        = string
  default     = "ami-04d5a0c96750aca25"  # CI/CD로 생성된 AMI (KTB Chat Backend)
}

# 백엔드 애플리케이션 설정
variable "backend_app_port" {
  description = "백엔드 애플리케이션 포트"
  type        = number
  default     = 5001  # 실제 백엔드 서버 포트
}

# 모니터링 설정
variable "enable_detailed_monitoring" {
  description = "세부 CloudWatch 모니터링 활성화"
  type        = bool
  default     = true
}

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch 로그 보존 기간 (일)"
  type        = number
  default     = 7
}

# 헬스체크 설정
variable "health_check_path" {
  description = "헬스체크 경로"
  type        = string
  default     = "/health"
}

variable "health_check_interval" {
  description = "헬스체크 간격 (초)"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "헬스체크 타임아웃 (초)"
  type        = number
  default     = 5
}

variable "healthy_threshold" {
  description = "정상 임계값"
  type        = number
  default     = 2
}

variable "unhealthy_threshold" {
  description = "비정상 임계값"
  type        = number
  default     = 2
}

# IAM 설정
variable "iam_instance_profile_name" {
  description = "IAM Instance Profile 이름 (CloudWatch Agent용)"
  type        = string
  default     = ""  # 빈 값 = IAM 역할 사용 안 함
} 