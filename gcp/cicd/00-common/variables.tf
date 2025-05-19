# common/variables.tf - 공통 변수 정의

# 프로젝트 관련 변수
variable "project_name" {
  description = "GCP 프로젝트 이름"
  type        = string
}

variable "project_id" {
  description = "GCP 프로젝트 ID"
  type        = string
}

# 환경 관련 변수
variable "environment" {
  description = "배포 환경 (dev, staging, prod)"
  type        = string
}

# 리전 관련 변수
variable "region" {
  description = "GCP 기본 리전"
  type        = string
}

variable "zone_suffix" {
  description = "GCP 존 접미사(a, b, c 등)"
  type        = string
}

# 공통 태그 관련 변수
variable "common_tags" {
  description = "모든 리소스에 적용할 공통 태그"
  type        = list(string)
}

# 공통 라벨 관련 변수
variable "common_labels" {
  description = "공통 라벨 (GCP 리소스 관리 및 비용 추적용)"
  type        = map(string)
}

# 도메인 관련 변수
variable "domain_name" {
  description = "서비스 도메인 이름"
  type        = string
}

# 상태 저장 관련 변수
variable "tfstate_bucket" {
  description = "테라폼 상태 저장용 GCS 버킷 이름"
  type        = string
}

variable "tfstate_region" {
  description = "테라폼 상태 저장용 GCS 버킷 리전"
  type        = string
}

# 네트워크 관련 변수
variable "network_name" {
  description = "기본 네트워크 이름"
  type        = string
}