# common/outputs.tf - 공통 출력 변수 정의

# 프로젝트 관련 출력
output "project_name" {
  description = "GCP 프로젝트 이름"
  value       = var.project_name
}

output "project_id" {
  description = "GCP 프로젝트 ID"
  value       = var.project_id
}

# 환경 관련 출력
output "environment" {
  description = "배포 환경 (dev, staging, prod)"
  value       = var.environment
}

# 리전 관련 출력
output "region" {
  description = "GCP 리전"
  value       = var.region
}

output "zone" {
  description = "GCP 존"
  value       = "${var.region}-${var.zone_suffix}"
}

# 공통 태그 관련 출력
output "common_tags" {
  description = "공통 태그"
  value       = var.common_tags
}

# 도메인 관련 출력
output "domain_name" {
  description = "서비스 도메인 이름"
  value       = var.domain_name
}

# 상태 저장 관련 출력
output "tfstate_bucket" {
  description = "테라폼 상태 저장용 GCS 버킷 이름"
  value       = var.tfstate_bucket
}

output "tfstate_region" {
  description = "테라폼 상태 저장용 GCS 버킷 리전"
  value       = var.tfstate_region
}

# 네트워크 관련 출력
output "network_name" {
  description = "VPC 네트워크 이름"
  value       = var.network_name
}

# 기타 공통 설정 출력
output "service_prefix" {
  description = "서비스 리소스 이름 접두어"
  value       = "${var.project_name}-${var.environment}"
}

output "common_labels" {
  description = "공통 라벨"
  value       = var.common_labels
}
