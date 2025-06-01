output "discord_webhooks_secret_arn" {
  description = "Discord webhooks secret ARN"
  value       = aws_secretsmanager_secret.discord_webhooks.arn
}

output "discord_webhook_url" {
  description = "Discord webhook URL"
  value       = jsondecode(aws_secretsmanager_secret_version.discord_webhooks.secret_string).frontend_webhook
  sensitive   = true
}

output "discord_webhook_url_all" {
  description = "Discord webhook URL"
  value       = jsondecode(aws_secretsmanager_secret_version.discord_webhooks.secret_string).backend_webhook
  sensitive   = true
}

output "db_password_secret_arn" {
  description = "Database password secret ARN"
  value       = aws_secretsmanager_secret.db_password.arn
}

output "db_password" {
  description = "Database password"
  value       = aws_secretsmanager_secret_version.db_password.secret_string
  sensitive   = true
}

output "app_storage_bucket_arn" {
  description = "애플리케이션 스토리지 S3 버킷 ARN"
  value       = aws_s3_bucket.app_storage.arn
}

output "app_storage_bucket_name" {
  description = "애플리케이션 스토리지 S3 버킷 이름"
  value       = aws_s3_bucket.app_storage.bucket
}

