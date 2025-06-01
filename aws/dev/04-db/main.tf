#-------------------------------
# 1. MySQL용 보안 그룹 생성
#-------------------------------
resource "aws_security_group" "mysql_sg" {
  name        = "${local.project_name}-${local.environment}-mysql-sg"
  description = "Security group for MySQL EC2 instance"
  vpc_id      = local.vpc_id

  # SSH 접속 허용 (22번 포트)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "For SSH access"
  }

  # MySQL 접속 허용 (3306번 포트)
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"]  # VPC 내부 전체에서 접속 가능. 나중엔 백엔드에서만 되는걸로 바꾸자.
    description = "For MySQL access"
  }

  # 모든 아웃바운드 트래픽 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-mysql-sg"
  })
}

#-------------------------------
# 2. IAM 역할 및 정책 설정
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

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-db-role"
  })
}

# S3 버킷 접근을 위한 IAM 정책
resource "aws_iam_policy" "s3_backup_policy" {
  name        = "${local.project_name}-${local.environment}-s3-backup-policy"
  description = "Policy to allow DB instance to upload backups to S3"
  
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
          "arn:aws:s3:::${local.s3_bucket_name}",
          "arn:aws:s3:::${local.s3_bucket_name}/*"
        ]
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-s3-backup-policy"
  })
}

# IAM 역할에 정책 연결
resource "aws_iam_role_policy_attachment" "s3_backup_policy_attachment" {
  role       = aws_iam_role.db_instance_role.name
  policy_arn = aws_iam_policy.s3_backup_policy.arn
}

# EC2 인스턴스 프로필 생성
resource "aws_iam_instance_profile" "db_instance_profile" {
  name = "${local.project_name}-${local.environment}-db-profile"
  role = aws_iam_role.db_instance_role.name
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-db-profile"
  })
}

#-------------------------------
# 3. MySQL용 EC2 인스턴스 생성
#-------------------------------
resource "aws_instance" "mysql" {
  ami                    = "ami-05a7f3469a7653972"  # Ubuntu 22.04 LTS
  instance_type          = "t3.small"  # 소규모 데이터베이스에 적합한 사이즈
  key_name               = "pumati-full-master"  # 키 페어 이름
  subnet_id              = local.subnet_id
  vpc_security_group_ids = [aws_security_group.mysql_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.db_instance_profile.name  # IAM 프로필 연결

  # EBS 루트 볼륨 설정
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20  # 20GB
    delete_on_termination = true
    encrypted             = true

    tags = merge(local.common_tags, {
      Name = "${local.project_name}-${local.environment}-mysql-root-volume"
    })
  }

  # MySQL을 설치하기 위한 사용자 데이터 스크립트 (외부 파일 사용)
  user_data = local.startup_script

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-mysql"
  })
}
