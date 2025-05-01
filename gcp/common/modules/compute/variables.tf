# modules/compute/variables.tf - 컴퓨팅 모듈 변수 정의

# 프로젝트 관련 필수 변수
variable "project_id" {
  description = "GCP 프로젝트 ID"
  type        = string
}

variable "region" {
  description = "GCP 리전 (예: us-central1, asia-northeast3)"
  type        = string
}

variable "zone" {
  description = "GCP 존 (리전 내 특정 데이터센터, 예: us-central1-a)"
  type        = string
}

# 인스턴스 관련 필수 변수
variable "instance_name" {
  description = "인스턴스 이름"
  type        = string
}

variable "machine_type" {
  description = "인스턴스 머신 타입"
  type        = string
}

# 스팟 인스턴스 설정
variable "spot" {
  description = "스팟 인스턴스 사용 여부"
  type        = bool
}

# 디스크 관련 변수
variable "image" {
  description = "부팅 디스크 이미지"
  type        = string
}

variable "boot_disk_size" {
  description = "부팅 디스크 크기(GB)"
  type        = number
}

variable "boot_disk_type" {
  description = "부팅 디스크 유형 (pd-standard, pd-ssd 등)"
  type        = string
}

# GPU 관련 변수
variable "gpu_type" {
  description = "GPU 유형 (예: 'nvidia-tesla-t4', 'nvidia-tesla-v100' 등)"
  type        = string
}

variable "gpu_count" {
  description = "GPU 개수"
  type        = number
}

# 네트워크 설정
variable "network" {
  description = "사용할 네트워크"
  type        = string
}

# 서비스 계정 관련 변수
variable "service_account_email" {
  description = "서비스 계정 이메일"
  type        = string
}

variable "service_account_scopes" {
  description = "서비스 계정 스코프"
  type        = list(string)
}

# 메타데이터 및 스크립트
variable "startup_script" {
  description = "인스턴스 시작 스크립트"
  type        = string
}

variable "additional_metadata" {
  description = "추가 메타데이터"
  type        = map(string)
}

# 태그 및 라벨
variable "tags" {
  description = "인스턴스 태그 (방화벽 규칙 등에 사용)"
  type        = list(string)
}

variable "labels" {
  description = "인스턴스 라벨 (리소스 관리 및 비용 추적에 사용)"
  type        = map(string)
} 