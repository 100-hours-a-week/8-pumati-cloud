# outputs.tf - 출력 변수 정의 파일

output "project_name" {
  description = "프로젝트 이름"
  value       = var.project_name
}

output "environment" {
  description = "환경 (dev, staging, prod)"
  value       = var.environment
}

output "region" {
  description = "AWS 리전"
  value       = var.region
}

output "common_tags" {
  description = "모든 리소스에 적용될 공통 태그"
  value       = var.common_tags
}

output "domain_name" {
  description = "서비스 도메인 이름"
  value       = var.domain_name
}

output "tfstate_bucket" {
  description = "테라폼 상태를 저장할 S3 버킷 이름"
  value       = var.tfstate_bucket
}

output "tfstate_region" {
  description = "테라폼 상태 버킷이 위치한 리전"
  value       = var.tfstate_region
}