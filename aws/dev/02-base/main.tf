# 디스코드 웹훅 URL을 위한 시크릿 매니저 설정
resource "aws_secretsmanager_secret" "discord_webhooks" {
  name        = "${local.project_name}-${local.environment}-discord-webhooks"
  description = "Discord webhook URLs for notifications"
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-discord-webhooks"
  })
}

# 시크릿 값 설정
resource "aws_secretsmanager_secret_version" "discord_webhooks" {
  secret_id     = aws_secretsmanager_secret.discord_webhooks.id
  secret_string = jsonencode({
    frontend_webhook = var.discord_webhook_url,
    backend_webhook  = var.discord_webhook_url_all
  })
}
