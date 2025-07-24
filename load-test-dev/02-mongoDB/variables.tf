# load-test-dev/02-mongoDB/variables.tf
# MongoDB 설정 변수 - 단일 인스턴스

variable "mongodb_instance_type" {
  description = "MongoDB 인스턴스 타입"
  type        = string
  default     = "t3.small"
}

variable "mongodb_volume_size" {
  description = "MongoDB EBS 볼륨 크기 (GB)"
  type        = number
  default     = 20
}

variable "enable_monitoring" {
  description = "인스턴스 모니터링 활성화 여부"
  type        = bool
  default     = true
} 