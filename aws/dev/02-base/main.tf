# S3 버킷 생성
resource "aws_s3_bucket" "app_storage" {
  bucket = "${local.project_name}-${local.environment}-db-backup"
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-db-backup"
  })
}

# S3 버킷 버전 관리 설정
resource "aws_s3_bucket_versioning" "app_storage_versioning" {
  bucket = aws_s3_bucket.app_storage.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 버킷 서버 측 암호화 설정
resource "aws_s3_bucket_server_side_encryption_configuration" "app_storage_encryption" {
  bucket = aws_s3_bucket.app_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 버킷 공개 액세스 차단 설정
resource "aws_s3_bucket_public_access_block" "app_storage_public_access_block" {
  bucket = aws_s3_bucket.app_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 디스코드 웹훅 URL을 위한 시크릿 매니저 설정
resource "aws_secretsmanager_secret" "discord_webhooks" {
  name        = "${local.project_name}-${local.environment}-discord-webhooks"
  description = "Discord webhook URLs for notifications"
  recovery_window_in_days = 0
  
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

resource "aws_secretsmanager_secret" "db_password" {
  name        = "${local.project_name}-${local.environment}-db-password"
  description = "Database password"
  recovery_window_in_days = 0

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-db-password"
  })
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_password
}
