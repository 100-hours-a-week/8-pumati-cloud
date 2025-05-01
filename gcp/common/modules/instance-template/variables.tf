# modules/mig/variables.tf - MIG 모듈 변수 정의

# 프로젝트 관련 변수
variable "project_id" {
  description = "GCP 프로젝트 ID"
  type        = string
}

variable "region" {
  description = "GCP 리전"
  type        = string
}

variable "zone" {
  description = "GCP 존"
  type        = string
}

# 인스턴스 관련 변수
variable "instance_name" {
  description = "인스턴스 이름"
  type        = string
}

variable "machine_type" {
  description = "인스턴스 머신 타입"
  type        = string
}

variable "base_instance_name" {
  description = "MIG 기본 인스턴스 이름"
  type        = string
}

variable "target_size" {
  description = "MIG 대상 크기"
  type        = number
  default     = 1
}

# 디스크 관련 변수
variable "image" {
  description = "부팅 디스크 이미지"
  type        = string
  default     = "debian-cloud/debian-11"
}

variable "boot_disk_size" {
  description = "부팅 디스크 크기(GB)"
  type        = number
  default     = 50
}

variable "boot_disk_type" {
  description = "부팅 디스크 유형"
  type        = string
  default     = "pd-standard"
}

# GPU 관련 변수
variable "gpu_type" {
  description = "GPU 유형"
  type        = string
  default     = "nvidia-tesla-t4"
}

variable "gpu_count" {
  description = "GPU 개수"
  type        = number
  default     = 1
}

# 서비스 계정 관련 변수
variable "service_account_email" {
  description = "서비스 계정 이메일"
  type        = string
  default     = ""  # 기본값은 프로젝트의 기본 서비스 계정
}

variable "service_account_scopes" {
  description = "서비스 계정 스코프"
  type        = list(string)
  default     = ["https://www.googleapis.com/auth/cloud-platform"]
}

# 기타 설정 변수
variable "startup_script" {
  description = "인스턴스 시작 스크립트"
  type        = string
  default     = ""
} 