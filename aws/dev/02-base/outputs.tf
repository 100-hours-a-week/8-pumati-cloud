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