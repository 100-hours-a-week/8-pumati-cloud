# load-test-dev/04-redis/variables.tf
# Redis 마스터-슬레이브 구성 변수

# ===============================
# 인스턴스 설정
# ===============================

variable "instance_type" {
  description = "Redis 인스턴스 타입"
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "SSH 키페어 이름"
  type        = string
  default     = "8-ktb-chat-keypair"
}

variable "ami_id" {
  description = "Redis 인스턴스용 AMI ID"
  type        = string
  default     = "ami-0a6f55b9b219e3e66"  # Ubuntu 22.04 LTS
}

# ===============================
# Redis 설정
# ===============================

variable "redis_port" {
  description = "Redis 포트"
  type        = number
  default     = 6379
}

variable "redis_maxmemory" {
  description = "Redis 최대 메모리 (MB)"
  type        = string
  default     = "1600mb"  # t3.small 메모리의 80%
}

variable "redis_maxmemory_policy" {
  description = "Redis 메모리 정책"
  type        = string
  default     = "allkeys-lru"
}

variable "redis_timeout" {
  description = "Redis 연결 타임아웃 (초)"
  type        = number
  default     = 300
}

variable "redis_maxclients" {
  description = "Redis 최대 클라이언트 연결 수"
  type        = number
  default     = 10000
}

# ===============================
# 모니터링 설정
# ===============================

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

# ===============================
# 네트워크 설정
# ===============================

variable "allow_external_ssh" {
  description = "외부에서 SSH 접근 허용 여부 (부하테스트용)"
  type        = bool
  default     = true
}

variable "redis_external_access" {
  description = "외부에서 Redis 직접 접근 허용 여부"
  type        = bool
  default     = false  # 보안상 기본적으로 비활성화
} 