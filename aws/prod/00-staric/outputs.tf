output "common_storage_bucket" {
  value = module.common_storage.bucket_name
  description = "공용 S3 버킷 이름"
} 