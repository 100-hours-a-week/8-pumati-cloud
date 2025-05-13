output "terraform_state_bucket" {
  value = module.terraform_state.bucket_name
  description = "Terraform state 저장용 S3 버킷 이름"
}

output "monitoring_logs_bucket" {
  value = module.monitoring_logs.bucket_name
  description = "모니터링 로그 수집용 S3 버킷 이름"
}

output "common_storage_bucket" {
  value = module.common_storage.bucket_name
  description = "공용 S3 버킷 이름"
} 