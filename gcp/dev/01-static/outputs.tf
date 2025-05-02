# outputs.tf - 출력 변수 정의 파일

output "bucket_name" {
  description = "생성된 버킷의 이름"
  value       = module.gcs.bucket_name
}

output "bucket_url" {
  description = "생성된 버킷의 URL"
  value       = module.gcs.bucket_url
}

output "bucket_self_link" {
  description = "생성된 버킷의 자체 링크"
  value       = module.gcs.bucket_self_link
}