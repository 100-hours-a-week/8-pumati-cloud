# ---------------------------------------------------------------------------------------------------------------------
# 보안 그룹
# ---------------------------------------------------------------------------------------------------------------------
module "frontend_sg" {
  source        = "../../common/module/sg"

  # 공통 입력값
  project_name  = local.project_name
  environment   = local.environment
  tags          = local.common_tags
  service_name  = "frontend-test"

  # 리소스 고유값
  vpc_id        = local.vpc_id

  ingress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["211.244.225.211/32", "10.0.0.0/16"]  # Shared VPC CIDR 추가
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
    },
    {
      from_port        = 3000
      to_port          = 3000
      protocol         = "tcp"
      security_groups  = [module.alb_sg.security_group_id]  # ALB 접근도 허용
      description      = "Allow from ALB"
    }
  ]
}

module "backend_sg" {
  source        = "../../common/module/sg"

  # 공통 값
  project_name  = local.project_name
  environment   = local.environment
  tags          = local.common_tags
  service_name  = "backend-test"

  # 리소스 고유값
  vpc_id        = local.vpc_id

  # 인바운드 규칙
  ingress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0", "10.0.0.0/16"]
      description = "SSH"
    },
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = ["10.3.0.228/32"]  # 기존 특정 IP 접근 유지
      description = "Backend API from specific IP"
    },
    {
      from_port        = 8080
      to_port          = 8080
      protocol         = "tcp"
      security_groups  = [module.alb_sg.security_group_id]  # ALB 접근도 허용
      description      = "Allow from ALB"
    }
  ]
}

module "management_sg" {
  source        = "../../common/module/sg"

  # 공통 값
  project_name  = local.project_name
  environment   = local.environment
  tags          = local.common_tags
  service_name  = "management-test"

  # 리소스 고유값
  vpc_id        = local.vpc_id

  # 인바운드 규칙
  ingress_rules = [
    {
      # ssh는 cidr 내ip로 수정할 것
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0", "10.0.0.0/16"]  # Shared VPC CIDR 추가
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

module "alb_sg" {
  source        = "../../common/module/sg"

  # 공통 입력값
  project_name  = local.project_name
  environment   = local.environment
  tags          = local.common_tags
  service_name  = "alb-test"

  # 리소스 고유값
  vpc_id        = local.vpc_id
  
  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTP from anywhere"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTPS from anywhere"
    }
  ]
}
# ---------------------------------------------------------------------------------------------------------------------
# IAM 규칙
# ---------------------------------------------------------------------------------------------------------------------
module "frontend_iam" {
  source        = "../../common/module/iam_role"
  project_name  = local.project_name
  environment   = local.environment
  service_name  = "frontend-test"
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
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:ListImages",
          "ecr:DescribeRepositories"
        ],
        Resource = "arn:aws:ecr:ap-northeast-2:236450698266:repository/pumati-prod-frontend-ecr"
      }
    ]
  })
}

module "backend_iam" {
  source        = "../../common/module/iam_role"
  project_name  = local.project_name
  environment   = local.environment
  service_name  = "backend-test"
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
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      Resource = "*"
      }
    ]
  })
}

module "management_iam" {
  source        = "../../common/module/iam_role"
  project_name  = local.project_name
  environment   = local.environment
  service_name  = "management-test"
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
module "frontend_env_secret_prod" {
  source = "../../common/module/secretsmanager"

  project_name  = local.project_name
  environment   = "prod"
  service_name  = "frontend-test"
  tags          = local.common_tags
  env_file_path = "../../common/envs/frontend/prod/.env"
  kms_key_id    = "arn:aws:kms:ap-northeast-2:236450698266:key/93a8affe-a6f3-4f22-bdcc-dfafac23e42d"
}
module "backend_env_secret_prod" {
  source = "../../common/module/secretsmanager"

  project_name  = local.project_name
  environment   = "prod"
  service_name  = "backend-test"
  tags          = local.common_tags
  env_file_path = "../../common/envs/backend/prod/.env"
  kms_key_id    = "arn:aws:kms:ap-northeast-2:236450698266:key/93a8affe-a6f3-4f22-bdcc-dfafac23e42d"
}