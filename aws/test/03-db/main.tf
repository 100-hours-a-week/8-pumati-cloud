#-------------------------------
# 1. DB 비밀번호 시크릿 매니저 생성
#-------------------------------
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${local.project_name}-${local.environment}-db-password"
  description             = "MySQL database password for test environment"
  recovery_window_in_days = 0 # test 환경이므로 즉시 삭제 가능

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-db-password"
      Type = "Database Credentials"
    }
  )
}

# DB 비밀번호 시크릿 값 설정 (비밀번호만 저장)
resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_password # 비밀번호만 저장

  lifecycle {
    ignore_changes = [secret_string] # 수동 변경 시 테라폼이 덮어쓰지 않도록 방지
  }
}

#-------------------------------
# 2. MySQL용 보안 그룹 생성
#-------------------------------
resource "aws_security_group" "mysql_sg" {
  name        = "${local.project_name}-${local.environment}-mysql-sg"
  description = "Security group for MySQL EC2 instance"
  vpc_id      = local.vpc_id

  # SSH 접속 허용 (22번 포트) - test 환경이므로 개방
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access for testing"
  }

  # MySQL 접속 허용 (3306번 포트) - VPC 내부에서만
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr_block]
    description = "MySQL access from VPC"
  }

  # 모든 아웃바운드 트래픽 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-mysql-sg"
      Type = "Database Security Group"
    }
  )
}

#-------------------------------
# 3. IAM 역할 및 정책 설정
#-------------------------------
# EC2 인스턴스에 부여할 IAM 역할
resource "aws_iam_role" "db_instance_role" {
  name = "${local.project_name}-${local.environment}-db-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-db-role"
      Type = "Database IAM Role"
    }
  )
}

# Secrets Manager 접근을 위한 IAM 정책
resource "aws_iam_policy" "secrets_manager_policy" {
  name        = "${local.project_name}-${local.environment}-secrets-manager-policy"
  description = "Policy to allow DB instance to read secrets from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.db_password.arn
        ]
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-secrets-manager-policy"
      Type = "Secrets Manager Policy"
    }
  )
}

# S3 백업 버킷 접근을 위한 IAM 정책
resource "aws_iam_policy" "s3_backup_policy" {
  name        = "${local.project_name}-${local.environment}-s3-backup-policy"
  description = "Policy to allow DB instance to upload backups to S3 and download scripts"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          # DB 백업 버킷 권한
          "arn:aws:s3:::${local.s3_bucket_name}",
          "arn:aws:s3:::${local.s3_bucket_name}/*",
          # Terraform state 버킷 권한 (스크립트 다운로드용)
          "arn:aws:s3:::${local.tfstate_bucket}",
          "arn:aws:s3:::${local.tfstate_bucket}/scripts/*"
        ]
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-s3-backup-policy"
      Type = "S3 Access Policy"
    }
  )
}

# CloudWatch Logs 접근을 위한 IAM 정책
resource "aws_iam_policy" "cloudwatch_policy" {
  name        = "${local.project_name}-${local.environment}-db-cloudwatch-policy"
  description = "Policy to allow DB instance to write logs to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${local.region}:*:*"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-db-cloudwatch-policy"
      Type = "CloudWatch Policy"
    }
  )
}

# IAM 역할에 정책들 연결
resource "aws_iam_role_policy_attachment" "secrets_manager_policy_attachment" {
  role       = aws_iam_role.db_instance_role.name
  policy_arn = aws_iam_policy.secrets_manager_policy.arn
}

resource "aws_iam_role_policy_attachment" "s3_backup_policy_attachment" {
  role       = aws_iam_role.db_instance_role.name
  policy_arn = aws_iam_policy.s3_backup_policy.arn
}

resource "aws_iam_role_policy_attachment" "cloudwatch_policy_attachment" {
  role       = aws_iam_role.db_instance_role.name
  policy_arn = aws_iam_policy.cloudwatch_policy.arn
}

# Session Manager 접근을 위한 IAM 정책 연결 (추가!)
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.db_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# EC2 인스턴스 프로필 생성
resource "aws_iam_instance_profile" "db_instance_profile" {
  name = "${local.project_name}-${local.environment}-db-profile"
  role = aws_iam_role.db_instance_role.name

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-db-profile"
      Type = "Database Instance Profile"
    }
  )
}

#-------------------------------
# 3. DB Startup Script S3 업로드
#-------------------------------
resource "aws_s3_object" "db_startup_script" {
  bucket = local.tfstate_bucket # pumati-s3-jacky
  key    = "scripts/db-script.sh"
  source = "${path.module}/scripts/db-script.sh"
  etag   = filemd5("${path.module}/scripts/db-script.sh")

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-db-script"
      Type = "Database Script"
    }
  )
}

#-------------------------------
# 4. MySQL용 EC2 인스턴스 생성 (수정)
#-------------------------------
resource "aws_instance" "mysql" {
  ami                    = "ami-05377cf8cfef186c2" # 아마존 리눅스 2023
  instance_type          = "t3.small"              # test 환경용 소형 인스턴스
  key_name               = "pumati-full-master"    # 키 페어 이름
  subnet_id              = local.db_subnet_ids[0]  # DB 서브넷 첫 번째 사용
  vpc_security_group_ids = [aws_security_group.mysql_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.db_instance_profile.name

  # EBS 루트 볼륨 설정
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 50 
    delete_on_termination = true
    encrypted             = true

    tags = merge(
      local.common_tags,
      {
        Name = "${local.project_name}-${local.environment}-mysql-root-volume"
        Type = "Database Storage"
      }
    )
  }

  # S3에서 startup script 다운로드 후 실행
  user_data = base64encode(templatefile("${path.module}/scripts/startup-script.sh", {
    project_name            = local.project_name
    environment             = local.environment
    db_name                 = local.db_name
    db_username             = local.db_username
    db_password_secret_name = local.db_password_secret_name
    s3_bucket_name          = local.tfstate_bucket
    aws_region              = local.tfstate_region
  }))

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-mysql"
      Type = "Database Server"
    }
  )

  # 인스턴스 종료 방지 (실수로 삭제 방지)
  lifecycle {
    prevent_destroy = false
  }

  depends_on = [
    aws_secretsmanager_secret_version.db_password,
    aws_s3_object.db_startup_script  # S3 업로드 후 인스턴스 생성
  ]
}

#-------------------------------
# 5. CloudWatch 로그 그룹 생성
#-------------------------------
resource "aws_cloudwatch_log_group" "mysql_logs" {
  name              = "/aws/ec2/${local.project_name}-${local.environment}-mysql"
  retention_in_days = 7 # test 환경이므로 7일만 보관

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-mysql-logs"
      Type = "Database Logs"
    }
  )
}

#-------------------------------
# 6. 알람 설정 (간단한 모니터링)
#-------------------------------
resource "aws_cloudwatch_metric_alarm" "mysql_cpu_utilization" {
  alarm_name          = "${local.project_name}-${local.environment}-mysql-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [] # test 환경이므로 알림 액션 없음

  dimensions = {
    InstanceId = aws_instance.mysql.id
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-mysql-cpu-alarm"
      Type = "Database Monitoring"
    }
  )
}
