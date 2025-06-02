# S3 버킷 관련 출력
output "db_backup_bucket_arn" {
  description = "DB 백업용 S3 버킷 ARN"
  value       = aws_s3_bucket.db_backup.arn
}

output "db_backup_bucket_name" {
  description = "DB 백업용 S3 버킷 이름"
  value       = aws_s3_bucket.db_backup.bucket
}

# 디스코드 웹훅 시크릿 관련 출력
output "discord_webhooks_secret_arn" {
  description = "디스코드 웹훅 시크릿 ARN"
  value       = aws_secretsmanager_secret.discord_webhooks.arn
}

output "discord_webhook_url" {
  description = "jacky용 디스코드 웹훅 URL"
  value       = jsondecode(aws_secretsmanager_secret_version.discord_webhooks.secret_string).discord_webhook_url
  sensitive   = true
}

output "discord_webhook_url_all" {
  description = "팀 전체용 디스코드 웹훅 URL"
  value       = jsondecode(aws_secretsmanager_secret_version.discord_webhooks.secret_string).discord_webhook_url_all
  sensitive   = true
}

# ACM 인증서 관련 출력
output "acm_certificate_arn" {
  description = "ACM 인증서 ARN"
  value       = aws_acm_certificate_validation.this.certificate_arn
}

output "acm_certificate_domain_name" {
  description = "ACM 인증서 도메인 이름"
  value       = aws_acm_certificate.this.domain_name
}
