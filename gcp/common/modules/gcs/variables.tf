# modules/gcs/variables.tf - 스토리지 모듈 변수 정의

# 프로젝트 관련 변수
variable "project_id" {
  description = "GCP 프로젝트 ID"
  type        = string
}

variable "region" {
  description = "GCP 리전 (예: asia-northeast3)"
  type        = string
}

# 버킷 관련 변수
variable "bucket_name" {
  description = "GCS 버킷 이름 (전역적으로 고유해야 함)"
  type        = string
}

variable "storage_class" {
  description = "스토리지 클래스 (예: STANDARD, NEARLINE, COLDLINE, ARCHIVE)"
  type        = string
}

# 버전 관리 관련 변수
variable "enable_versioning" {
  description = "버전 관리 활성화 여부 (true/false)"
  type        = bool
}

# 보안 관련 변수
variable "uniform_bucket_level_access" {
  description = "균일한 버킷 수준 액세스 설정 여부 (true/false)"
  type        = bool
}

# CORS 관련 변수
variable "cors_origins" {
  description = "CORS 오리진 리스트 (예: [\"*\"] 또는 [\"https://example.com\"])"
  type        = list(string)
}

variable "cors_methods" {
  description = "CORS 허용 메소드 리스트 (예: [\"GET\", \"HEAD\", \"OPTIONS\"])"
  type        = list(string)
}

variable "cors_response_headers" {
  description = "CORS 응답 헤더 리스트 (예: [\"*\"])"
  type        = list(string)
}

variable "cors_max_age_seconds" {
  description = "CORS 캐시 시간(초) (예: 3600)"
  type        = number
}

# 라벨 관련 변수
variable "environment" {
  description = "환경 (예: dev, staging, prod)"
  type        = string
}

variable "common_tags" {
  description = "Common 모듈에서 가져온 공통 태그"
  type        = map(string)
}

variable "additional_labels" {
  description = "버킷에 적용할 추가 라벨 (예: { team = \"data\" })"
  type        = map(string)
}

variable "managed_by" {
  description = "리소스 관리 도구 (예: terraform)"
  type        = string
} 