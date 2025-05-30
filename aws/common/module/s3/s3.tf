# ------------------------------------------------------------
# S3 버킷 생성
# ------------------------------------------------------------
resource "aws_s3_bucket" "this" {
    bucket = var.bucket_name
    force_destroy = var.force_destroy

    tags = merge(
        var.tags,
        {
            Name = var.bucket_name
        }
    )
}

# ------------------------------------------------------------
# 버킷 버전 관리 활성화
# ------------------------------------------------------------
resource "aws_s3_bucket_versioning" "this" {
    count = var.enable_versioning ? 1 : 0
    
    bucket = aws_s3_bucket.this.id
    versioning_configuration {
        status = "Enabled"  # 버전 관리 활성화로 테라폼 상태 변경사항 추적
    }
}

# ------------------------------------------------------------
# 수명 주기 정책 설정
# ------------------------------------------------------------
resource "aws_s3_bucket_lifecycle_configuration" "this" {
    count = var.enable_lifecycle_rule ? 1 : 0
    
    bucket = aws_s3_bucket.this.id

    rule {
        id = "expire-old-versions"
        status = "Enabled"

        filter {
            prefix = ""  # 모든 객체에 적용
        }

        noncurrent_version_expiration {
            noncurrent_days = var.lifecycle_rule_days  # 지정된 일수 후 오래된 버전 자동 삭제
        }
    }
}

# ------------------------------------------------------------
# 서버 사이드 암호화 설정
# ------------------------------------------------------------
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
    count = var.enable_encryption ? 1 : 0
    
    bucket = aws_s3_bucket.this.id

    rule {
        apply_server_side_encryption_by_default {
            sse_algorithm = var.encryption_algorithm
        }
    }
}

# ------------------------------------------------------------
# 퍼블릭 액세스 차단 설정
# ------------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "this" {
    count = var.block_public_access ? 1 : 0
    
    bucket = aws_s3_bucket.this.id
    block_public_acls       = var.block_public_acls
    block_public_policy     = var.block_public_policy
    ignore_public_acls      = var.ignore_public_acls
    restrict_public_buckets = var.restrict_public_buckets
}

# ------------------------------------------------------------
# 버킷 정책 설정
# ------------------------------------------------------------
resource "aws_s3_bucket_policy" "this" {
    count = length(var.terraform_state_user_arns) > 0 ? 1 : 0
    
    bucket = aws_s3_bucket.this.id
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Principal = {
                    AWS = var.terraform_state_user_arns
                }
                Action = var.allowed_actions
                Resource = [
                    aws_s3_bucket.this.arn,
                    "${aws_s3_bucket.this.arn}/*"
                ]
            }
        ]
    })
}
