# load-test-dev/03-compute/variables.tf
# Compute 리소스 설정 변수

# Auto Scaling Groups 설정
variable "backend_asg_desired" {
  description = "백엔드 ASG 기본 인스턴스 수"
  type        = number
  default     = 5  # 복원: 5개 인스턴스
}

variable "backend_asg_min" {
  description = "백엔드 ASG 최소 인스턴스 수"
  type        = number
  default     = 1  # 복원: 최소 1개
}

variable "backend_asg_max" {
  description = "백엔드 ASG 최대 인스턴스 수"
  type        = number
  default     = 15
}

variable "frontend_asg_desired" {
  description = "프론트엔드 ASG 기본 인스턴스 수"
  type        = number
  default     = 5  # 복원: 5개 인스턴스
}

variable "frontend_asg_min" {
  description = "프론트엔드 ASG 최소 인스턴스 수"
  type        = number
  default     = 1  # 복원: 최소 1개
}

variable "frontend_asg_max" {
  description = "프론트엔드 ASG 최대 인스턴스 수"
  type        = number
  default     = 15
}

# 인스턴스 설정
variable "instance_type" {
  description = "EC2 인스턴스 타입"
  type        = string
  default     = "t3.small"
}

variable "custom_backend_ami" {
  description = "백엔드용 커스텀 AMI ID"
  type        = string
  default     = "ami-0a875fa7e9ee1ba3d"  # 커스텀 AMI (Node.js + PM2 + CloudWatch Agent)
}

variable "custom_frontend_ami" {
  description = "프론트엔드용 커스텀 AMI ID"
  type        = string
  default     = "ami-0a875fa7e9ee1ba3d"  # 커스텀 AMI (Next.js + PM2 + CloudWatch Agent)
}

# 로드밸런서 설정
variable "enable_nlb" {
  description = "NLB 활성화 여부 (로드테스트에서는 불필요한 복잡성)"
  type        = bool
  default     = false  # ALB 단독 사용으로 변경
}

variable "backend_app_port" {
  description = "백엔드 애플리케이션 포트"
  type        = number
  default     = 3000
}

variable "frontend_app_port" {
  description = "프론트엔드 애플리케이션 포트"
  type        = number
  default     = 3000
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
  default     = 3
}

# 로컬 변수는 providers.tf에서 정의됨 