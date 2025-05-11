output "secret_id" {
  description = "생성된 시크릿의 ID"
  value       = google_secret_manager_secret.secret.id
}

output "secret_name" {
  description = "생성된 시크릿의 전체 이름"
  value       = google_secret_manager_secret.secret.name
}

output "version_name" {
  description = "생성된 시크릿 버전의 이름"
  value       = google_secret_manager_secret_version.secret_version.name
  sensitive   = true
}