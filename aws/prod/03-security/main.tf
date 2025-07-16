# ---------------------------------------------------------------------------------------------------------------------
# 보안 그룹
# ---------------------------------------------------------------------------------------------------------------------
# ALB Security Group
module "alb_sg" {
  source        = "../../common/module/sg"

  project_name  = local.project_name
  environment   = local.environment
  tags          = local.common_tags
  service_name  = "alb"

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

# Frontend Security Group
module "frontend_sg" {
  source        = "../../common/module/sg"

  project_name  = local.project_name
  environment   = local.environment
  tags          = local.common_tags
  service_name  = "frontend"

  vpc_id        = local.vpc_id

  ingress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]  # shared VPC에서 SSH 허용
      description = "Allow SSH from Shared VPC via OpenVPN"
    },
    {
      from_port        = 3000
      to_port          = 3000
      protocol         = "tcp"
      security_groups  = [module.alb_sg.security_group_id]  # ALB에서의 접근 허용
      description      = "Allow frontend access from ALB"
    },
    {
      from_port        = 9100
      to_port          = 9100
      protocol         = "tcp"
      cidr_blocks      = ["10.0.0.0/16"]  # Prometheus가 있는 shared VPC CIDR
      description      = "Allow Prometheus (node_exporter) access from Shared VPC"
    }
  ]
}

# Backend Security Group
module "backend_sg" {
  source        = "../../common/module/sg"

  project_name  = local.project_name
  environment   = local.environment
  tags          = local.common_tags
  service_name  = "backend"

  vpc_id        = local.vpc_id

  ingress_rules = [
    {
      from_port   = -1
      to_port     = -1
      protocol    = "icmp"
      cidr_blocks = ["10.0.0.0/16"]
      description = "Allow ICMP (ping) from Shared VPC"
    },
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]  # shared VPC에서 SSH 허용
      description = "Allow SSH from Shared VPC via OpenVPN"
    },
    {
      from_port        = 8080
      to_port          = 8080
      protocol         = "tcp"
      security_groups  = [module.alb_sg.security_group_id]  # ALB 접근 허용
      description      = "Allow backend API from ALB"
    },
    {
      from_port        = 8080
      to_port          = 8080
      protocol         = "tcp"
      security_groups  = [module.frontend_sg.security_group_id]  # 프론트에서의 API 호출 허용
      description      = "Allow API call from frontend"
    },
    {
      from_port        = 9100
      to_port          = 9100
      protocol         = "tcp"
      cidr_blocks      = ["10.0.0.0/16"]  # Prometheus가 있는 shared VPC CIDR
      description      = "Allow Prometheus (node_exporter) access from Shared VPC"
    }
  ]
}

# DB Security Group
module "db_sg" {
  source        = "../../common/module/sg"

  project_name  = local.project_name
  environment   = local.environment
  tags          = local.common_tags
  service_name  = "db"

  vpc_id        = local.vpc_id

  ingress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]  # shared VPC에서 SSH 허용
      description = "Allow SSH from Shared VPC via OpenVPN"
    },
    {
      from_port        = 3306
      to_port          = 3306
      protocol         = "tcp"
      security_groups  = [module.backend_sg.security_group_id]
      description      = "Allow MySQL from backend SG"
    },
    {
      from_port        = 9104
      to_port          = 9104
      protocol         = "tcp"
      cidr_blocks      = ["10.0.0.0/16"]  # Prometheus가 있는 shared VPC CIDR
      description      = "Allow Prometheus (mysqld_exporter) access from Shared VPC"
    }
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# IAM 규칙
# ---------------------------------------------------------------------------------------------------------------------
module "frontend_iam" {
  source                   = "../../common/module/iam_role"
  project_name             = local.project_name
  environment              = local.environment
  service_name             = "frontend"
  assume_role_service      = "ec2.amazonaws.com"
  instance_profile_enabled = true
  tags                     = local.common_tags

  enable_inline_policy  = true    
  enable_managed_policy = false   

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
  source                   = "../../common/module/iam_role"
  project_name             = local.project_name
  environment              = local.environment
  service_name             = "backend" 
  assume_role_service      = "ec2.amazonaws.com"
  instance_profile_enabled = true
  tags                     = local.common_tags 

  enable_inline_policy  = true    
  enable_managed_policy = false   

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

module "db_iam" {
  source        = "../../common/module/iam_role"
  project_name  = local.project_name
  environment   = local.environment
  service_name  = "db"
  assume_role_service     = "ec2.amazonaws.com"
  instance_profile_enabled = true
  tags          = local.common_tags

  enable_inline_policy  = true    
  enable_managed_policy = false   

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

module "firehose_iam" {
  source        = "../../common/module/iam_role"
  project_name  = local.project_name
  environment   = local.environment
  service_name  = "firehose"
  assume_role_service     = "firehose.amazonaws.com"
  instance_profile_enabled = false
  tags          = local.common_tags

  enable_inline_policy  = true    
  enable_managed_policy = false   

  inline_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPutToMonitoringS3"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObjectAcl",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::s3-pumati-monitoring-logs",
          "arn:aws:s3:::s3-pumati-monitoring-logs/*"
        ]
      },
      {
        Sid    = "AllowCWLogs"
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents"
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
  service_name  = "frontend"
  tags          = local.common_tags
  env_file_path = "../../common/envs/frontend/prod/.env"
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