# Route53 호스팅 존 데이터 소스 (기존 호스팅 존이 있다고 가정)
# 이미 호스팅 영역이 만들어져 있음(사놨으니까)
data "aws_route53_zone" "this" {
  name         = "tebutebu.com"  # 부모 도메인
  private_zone = false
}

# ACM 인증서 생성
resource "aws_acm_certificate" "this" {
  domain_name               = local.domain_name
  subject_alternative_names = ["*.${local.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-certificate"
    }
  )
}

# ACM 인증서 DNS 검증 레코드 생성
resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.this.zone_id
}

# ACM 인증서 검증 완료 대기
resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation : record.fqdn]

  timeouts {
    create = "5m"
  }
}
#--------------------------------
# DB 백업용 S3 버킷 (기본 설정만)
resource "aws_s3_bucket" "db_backup" {
  bucket = "${local.project_name}-${local.environment}-db-backup"

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.project_name}-${local.environment}-db-backup"
      Purpose     = "Test Database Backup Storage"
      Environment = local.environment
    }
  )
}

# S3 버킷 퍼블릭 액세스 차단
resource "aws_s3_bucket_public_access_block" "db_backup" {
  bucket = aws_s3_bucket.db_backup.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 버킷 버전 관리
resource "aws_s3_bucket_versioning" "db_backup" {
  bucket = aws_s3_bucket.db_backup.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 버킷 암호화
resource "aws_s3_bucket_server_side_encryption_configuration" "db_backup" {
  bucket = aws_s3_bucket.db_backup.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 버킷 라이프사이클 (test용 7일 보관)
resource "aws_s3_bucket_lifecycle_configuration" "db_backup" {
  bucket = aws_s3_bucket.db_backup.id

  rule {
    id     = "test_backup_cleanup"
    status = "Enabled"

    # 모든 객체에 적용하기 위한 빈 필터
    filter {
      prefix = ""
    }

    expiration {
      days = 7  # 7일 후 삭제
    }

    noncurrent_version_expiration {
      noncurrent_days = 3  # 이전 버전 3일 후 삭제
    }

    # 불완전한 멀티파트 업로드 정리
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

#--------------------------------
# 디스코드 웹훅 URL을 위한 시크릿 매니저 설정
resource "aws_secretsmanager_secret" "discord_webhooks" {
  name                    = "${local.project_name}-${local.environment}-discord-webhooks"
  description             = "Discord webhook URLs for test environment notifications"
  recovery_window_in_days = 0  # test 환경이므로 즉시 삭제 가능

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.project_name}-${local.environment}-discord-webhooks"
      Purpose     = "Discord Notification URLs"
      Environment = local.environment
    }
  )
}

# 디스코드 웹훅 시크릿 값 설정
resource "aws_secretsmanager_secret_version" "discord_webhooks" {
  secret_id = aws_secretsmanager_secret.discord_webhooks.id
  secret_string = jsonencode({
    discord_webhook_url     = var.discord_webhook_url      # jacky용 웹훅
    discord_webhook_url_all = var.discord_webhook_url_all  # 팀 전체용 웹훅
  })

  lifecycle {
    ignore_changes = [secret_string]  # 수동 변경 시 테라폼이 덮어쓰지 않도록 방지
  }
}


