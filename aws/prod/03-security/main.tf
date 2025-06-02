# ---------------------------------------------------------------------------------------------------------------------
# 보안 그룹
# ---------------------------------------------------------------------------------------------------------------------
module "frontend_sg" {
  source        = "../../common/module/sg"

  # 공통 입력값
  project_name  = local.project_name
  environment   = local.environment
  tags          = local.common_tags
  service_name  = "frontend"

  # 리소스 고유값
  name          = "${local.project_name}-${local.environment}-frontend-sg"
  description   = "프론트엔드 서비스용 보안 그룹"
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
  source        = "../../common/module/sg"

  # 공통 값
  project_name  = local.project_name
  environment   = local.environment
  tags          = local.common_tags
  service_name  = "backend"

  # 리소스 고유값
  name          = "${local.project_name}-${local.environment}-backend-sg"
  description   = "백엔드 서비스용 보안 그룹"
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

module "management_sg" {
  source        = "../../common/module/sg"

  # 공통 값
  project_name  = local.project_name
  environment   = local.environment
  tags          = local.common_tags
  service_name  = "management"

  # 리소스 고유값
  name          = "${local.project_name}-${local.environment}-management-sg"
  description   = "Management 서비스용 보안 그룹"
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
      description = "Management UI"
    },
    {
      from_port   = 50000
      to_port     = 50000
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Management Agent (optional)"
    }
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# IAM 규칙
# ---------------------------------------------------------------------------------------------------------------------
module "frontend_iam" {
  source        = "../../common/module/iam-role"
  project_name  = local.project_name
  environment   = local.environment
  service_name  = "frontend"
  tags          = local.common_tags

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
          "arn:aws:s3:::s3-pumati-common-storage",       
          "arn:aws:s3:::s3-pumati-common-storage/*"     
        ]
      }
    ]
  })
}

module "backend_iam" {
  source        = "../../common/module/iam-role"
  project_name  = local.project_name
  environment   = local.environment
  service_name  = "backend"
  tags          = local.common_tags

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
          "arn:aws:s3:::s3-pumati-common-storage",
          "arn:aws:s3:::s3-pumati-common-storage/*"
        ]
      }
    ]
  })
}

module "management_iam" {
  source        = "../../common/module/iam-role"
  project_name  = local.project_name
  environment   = local.environment
  service_name  = "management"
  tags          = local.common_tags

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
          "arn:aws:s3:::s3-pumati-common-storage",
          "arn:aws:s3:::s3-pumati-common-storage/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
        "secretsmanager:GetSecretValue"
      ]
      Resource = [
        "arn:aws:secretsmanager:ap-northeast-2:236450698266:secret:pumati-dev-frontend-.env*",
        "arn:aws:secretsmanager:ap-northeast-2:236450698266:secret:pumati-prod-frontend-.env*",
        "arn:aws:secretsmanager:ap-northeast-2:236450698266:secret:pumati-dev-backend-.env*",
        "arn:aws:secretsmanager:ap-northeast-2:236450698266:secret:pumati-prod-backend-.env*"
      ]
      },
      {
      Effect = "Allow"
      Action = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ]
      Resource = "*"
      }
    ]
  })
}
#---------------------------------------------------------------------------------------------------------------------
# Secrets Manager
#---------------------------------------------------------------------------------------------------------------------
module "frontend_env_secret_dev" {
  source = "../../common/module/secretsmanager"

  project_name  = local.project_name
  environment   = "dev"
  service_name  = "frontend"
  tags          = local.common_tags
  env_file_path = "../../common/envs/frontend/dev/.env"
  kms_key_id    = "arn:aws:kms:ap-northeast-2:236450698266:key/93a8affe-a6f3-4f22-bdcc-dfafac23e42d"
}

module "frontend_env_secret_prod" {
  source = "../../common/module/secretsmanager"

  project_name  = local.project_name
  environment   = "prod"
  service_name  = "frontend"
  tags          = local.common_tags
  env_file_path = "../../common/envs/frontend/prod/.env"
  kms_key_id    = "arn:aws:kms:ap-northeast-2:236450698266:key/93a8affe-a6f3-4f22-bdcc-dfafac23e42d"
}

module "backend_env_secret_dev" {
  source = "../../common/module/secretsmanager"

  project_name  = local.project_name
  environment   = "dev"
  service_name  = "backend"
  tags          = local.common_tags
  env_file_path = "../../common/envs/backend/dev/.env"
  kms_key_id    = "arn:aws:kms:ap-northeast-2:236450698266:key/93a8affe-a6f3-4f22-bdcc-dfafac23e42d"
}

module "backend_env_secret_prod" {
  source = "../../common/module/secretsmanager"

  project_name  = local.project_name
  environment   = "prod"
  service_name  = "backend"
  tags          = local.common_tags
  env_file_path = "../../common/envs/backend/prod/.env"
  kms_key_id    = "arn:aws:kms:ap-northeast-2:236450698266:key/93a8affe-a6f3-4f22-bdcc-dfafac23e42d"
}