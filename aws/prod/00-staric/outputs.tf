output "common_storage_bucket" {
  value = module.common_storage.bucket_name
  description = "공용 S3 버킷 이름"
} 

output "terraform_state_bucket" {
  value = module.terraform_state.bucket_name
  description = "테라폼 상태 저장용 S3 버킷 이름"
}

