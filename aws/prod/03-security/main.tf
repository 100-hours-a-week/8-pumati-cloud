# ---------------------------------------------------------------------------------------------------------------------
# 보안 그룹
# ---------------------------------------------------------------------------------------------------------------------
module "frontend_sg" {
  source        = "./modules/security-group"

  # 공통 입력값
  project_name  = local.project_name
  environment   = local.environment
  region        = local.region
  tags          = local.common_tags
  instance_name = "frontend"

  # 리소스 고유값
  name          = "${local.project_name}-${local.environment}-frontend-sg"
  description   = "프론트엔드 인스턴스용 보안 그룹"
  vpc_id        = local.vpc_id

  ingress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      # ssh는 cidr 내ip로 수정할 것
      cidr_blocks = ["0.0.0.0/0"]
      description = "SSH"
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS"
    }
  ]
}

module "backend_sg" {
  source        = "./modules/security-group"

  # 공통 값
  project_name  = local.project_name
  environment   = local.environment
  region        = local.region
  tags          = local.common_tags
  instance_name = "backend"

  # 리소스 고유값
  name          = "${local.project_name}-${local.environment}-backend-sg"
  description   = "백엔드 인스턴스용 보안 그룹"
  vpc_id        = local.vpc_id

  # 인바운드 규칙
  ingress_rules = [
    {
      # ssh는 cidr 내ip로 수정할 것
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "SSH"
    },
    {
      from_port       = 8080
      to_port         = 8080
      protocol        = "tcp"
      security_groups = [module.frontend_sg.security_group_id]
      description     = "Frontend to Backend"
    }
  ]
}

module "jenkins_sg" {
  source        = "./modules/security-group"

  # 공통 값
  project_name  = local.project_name
  environment   = local.environment
  region        = local.region
  tags          = local.common_tags
  instance_name = "jenkins"

  # 리소스 고유값
  name          = "${local.project_name}-${local.environment}-jenkins-sg"
  description   = "Jenkins 인스턴스용 보안 그룹"
  vpc_id        = local.vpc_id

  # 인바운드 규칙
  ingress_rules = [
    {
      # ssh는 cidr 내ip로 수정할 것
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "SSH"
    },
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Jenkins UI"
    },
    {
      from_port   = 50000
      to_port     = 50000
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Jenkins Agent (optional)"
    }
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# IAM 규칙
# ---------------------------------------------------------------------------------------------------------------------
module "frontend_iam" {
  source        = "./modules/iam-role"
  project_name  = local.project_name
  environment   = local.environment
  region        = local.region
  tags          = local.common_tags
  instance_name = "frontend"

  # 인라인 정책 정의
  inline_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::s3-common-storage-pumati",       
          "arn:aws:s3:::s3-common-storage-pumati/*"     
        ]
      }
    ]
  })
}

module "backend_iam" {
  source        = "./modules/iam-role"
  project_name  = local.project_name
  environment   = local.environment
  region        = local.region
  tags          = local.common_tags
  instance_name = "backend"

  # 인라인 정책 정의
  inline_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::s3-common-storage-pumati",
          "arn:aws:s3:::s3-common-storage-pumati/*"
        ]
      }
    ]
  })
}


module "jenkins_iam" {
  source        = "./modules/iam-role"
  project_name  = local.project_name
  environment   = local.environment
  region        = local.region
  tags          = local.common_tags
  instance_name = "jenkins"

  # 인라인 정책 정의
  inline_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::your-jenkins-bucket",
          "arn:aws:s3:::your-jenkins-bucket/*"
        ]
      }
    ]
  })
}