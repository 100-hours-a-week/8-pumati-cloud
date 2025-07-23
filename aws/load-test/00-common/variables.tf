# variables.tf - 변수 정의 파일

variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "environment" {
  description = "환경 (dev, staging, prod, test, shared)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod", "test", "shared", "load-test"], var.environment)
    error_message = "environment는 'dev', 'staging', 'prod', 'test', 'shared', 'load-test' 중 하나여야 합니다."
  }
}

variable "region" {
  description = "AWS 리전"
  type        = string
}

variable "common_tags" {
  description = "모든 리소스에 적용될 공통 태그"
  type        = map(string)
}

variable "domain_name" {
  description = "서비스 도메인 이름"
  type        = string
}

variable "tfstate_bucket" {
  description = "테라폼 상태를 저장할 S3 버킷 이름"
  type        = string
}

variable "tfstate_region" {
  description = "테라폼 상태 버킷이 위치한 리전"
  type        = string
}