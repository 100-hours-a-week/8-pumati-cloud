# modules/gcs/outputs.tf - 스토리지 모듈 출력 정의

output "bucket_name" {
  description = "생성된 버킷의 이름"
  value       = google_storage_bucket.bucket.name
}

output "bucket_url" {
  description = "생성된 버킷의 URL"
  value       = google_storage_bucket.bucket.url
}

output "bucket_self_link" {
  description = "생성된 버킷의 자체 링크"
  value       = google_storage_bucket.bucket.self_link
}

output "storage_class" {
  description = "버킷의 스토리지 클래스"
  value       = google_storage_bucket.bucket.storage_class
}