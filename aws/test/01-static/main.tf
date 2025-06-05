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

#==============================================================================
# Jenkins 마스터용 EBS 볼륨
#==============================================================================
# 🎯 Jenkins 전용 EBS 볼륨 생성 이유:
# 스팟 인스턴스 안정성: 노드가 종료되어도 Jenkins 데이터 보존
# 성능 최적화: GP3로 IOPS와 처리량 독립적 설정
# 확장성: 필요시 볼륨 크기 확장 가능


# Jenkins 마스터용 EBS 볼륨 생성
resource "aws_ebs_volume" "jenkins_master" {
  # 첫 번째 가용영역에 생성 (private subnet과 동일한 AZ)
  availability_zone = "ap-northeast-2a"
  
  # 볼륨 설정
  size = 50   # 50GB - Jenkins 설정, 빌드 기록, 플러그인 등
  type = "gp3"  # GP3: 비용 효율적이고 성능 좋음
  
  # GP3 성능 설정
  iops       = 3000   # 기본 3000 IOPS (충분함)
  throughput = 125    # 기본 125 MiB/s (충분함)
  
  # 보안 설정
  encrypted  = true   # 데이터 암호화
  # kms_key_id를 지정하지 않으면 기본 AWS 관리형 키 사용
  
  # 스냅샷 설정
  snapshot_id = null  # 새로운 볼륨 생성
  
  # 태그 설정
  tags = merge(
    local.common_tags,
    {
      Name        = "${local.project_name}-${local.environment}-jenkins-master-ebs"
      Purpose     = "Jenkins Master Data Storage"
      Component   = "CI-CD"
      Environment = local.environment
      VolumeType  = "jenkins-master"
      
      # Kubernetes에서 볼륨을 찾을 수 있지만 클러스터 삭제 시 보존되도록 shared 사용
      "kubernetes.io/cluster/${local.project_name}-${local.environment}-eks" = "shared"
      "kubernetes.io/created-for/pv/name" = "jenkins-master-pv"
    }
  )
  
  # 볼륨 삭제 방지 (실수로 삭제되지 않도록)
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      # 스냅샷에서 복원할 때 변경될 수 있는 속성들 무시
      snapshot_id,
    ]
  }
}

# Jenkins EBS 볼륨 자동 스냅샷 생성 (백업용)
resource "aws_dlm_lifecycle_policy" "jenkins_backup" {
  description        = "Jenkins EBS volume automatic snapshot policy"  # 영어로 변경
  execution_role_arn = aws_iam_role.dlm_lifecycle_role.arn
  state              = "ENABLED"

  policy_details {
    resource_types   = ["VOLUME"]
    target_tags = {
      VolumeType = "jenkins-master"
    }

    schedule {
      name = "jenkins-daily-backup"

      create_rule {
        interval      = 24  # 24시간마다
        interval_unit = "HOURS"
        times         = ["03:00"]  # 새벽 3시 (KST 12시)
      }

      retain_rule {
        count = 7  # 7일간 보관
      }

      tags_to_add = {
        SnapshotCreator = "DLM"
        SourceVolume    = "jenkins-master"
        Environment     = local.environment
      }

      copy_tags = true
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-jenkins-dlm-policy"
    }
  )
}

# DLM (Data Lifecycle Manager)용 IAM 역할
resource "aws_iam_role" "dlm_lifecycle_role" {
  name = "${local.project_name}-${local.environment}-dlm-lifecycle-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dlm.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-dlm-lifecycle-role"
    }
  )
}

# DLM 역할에 필요한 정책 연결
resource "aws_iam_role_policy_attachment" "dlm_lifecycle_policy" {
  role       = aws_iam_role.dlm_lifecycle_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSDataLifecycleManagerServiceRole"
}

#==============================================================================
# ECR (Elastic Container Registry) - 도커 이미지 저장소
#==============================================================================
# 🎯 ECR 생성 이유:
# Jenkins CI/CD: 빌드된 애플리케이션 이미지 저장
# 버전 관리: 이미지 태깅으로 릴리즈 버전 관리
# 보안: 프라이빗 저장소로 이미지 보안 유지
# 비용 최적화: 라이프사이클 정책으로 오래된 이미지 자동 삭제

# 백엔드 애플리케이션용 ECR
resource "aws_ecr_repository" "backend" {
  name                 = "${local.project_name}-${local.environment}-backend-ecr"
  image_tag_mutability = "MUTABLE"  # 태그 변경 허용 (개발 환경)

  image_scanning_configuration {
    scan_on_push = true  # 푸시 시 보안 스캔 자동 실행
  }

  encryption_configuration {
    encryption_type = "AES256"  # 기본 암호화
  }

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.project_name}-${local.environment}-backend-ecr"
      Purpose     = "Backend Application Images"
      Component   = "CI-CD"
      Environment = local.environment
      ImageType   = "backend"
    }
  )
}

# 프론트엔드 애플리케이션용 ECR
resource "aws_ecr_repository" "frontend" {
  name                 = "${local.project_name}-${local.environment}-frontend-ecr"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.project_name}-${local.environment}-frontend-ecr"
      Purpose     = "Frontend Application Images"
      Component   = "CI-CD"
      Environment = local.environment
      ImageType   = "frontend"
    }
  )
}

# ECR 라이프사이클 정책 (백엔드) - 오래된 이미지 자동 삭제
resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "release"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images older than 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ECR 라이프사이클 정책 (프론트엔드)
resource "aws_ecr_lifecycle_policy" "frontend" {
  repository = aws_ecr_repository.frontend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "release"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images older than 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ECR 저장소 정책 (선택사항) - 제거하여 기본 권한 사용
# resource "aws_ecr_repository_policy" "backend" {
#   repository = aws_ecr_repository.backend.name
#   policy = ...
# }

# resource "aws_ecr_repository_policy" "frontend" {
#   repository = aws_ecr_repository.frontend.name  
#   policy = ...
# }

# 현재 AWS 계정 ID 조회 (ECR 정책용)
data "aws_caller_identity" "current" {}


