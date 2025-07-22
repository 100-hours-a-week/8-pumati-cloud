module "alb_sg" {
  source = "../../common/module/sg"

  project_name  = local.project_name
  environment   = local.environment
  service_name  = "alb"
  tags          = local.common_tags
  vpc_id        = local.vpc_id

  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"] # VPN 사용자만 허용
      description = "Allow HTTP from VPN"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"] # VPN 사용자만 허용
      description = "Allow HTTPS from VPN"
    }
  ]
}

# 원래는 내 IP대역만 허용해야 하는데 네트워크 장비 교체하면 IP대역이 바뀌므로 일단 모두 허용
module "openvpn_sg" {
  source        = "../../common/module/sg"

  # 공통 값
  project_name  = local.project_name
  environment   = local.environment
  tags          = local.common_tags
  service_name  = "openvpn"

  # 리소스 고유값
  vpc_id        = local.vpc_id

  # 인바운드 규칙
  ingress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "SSH"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS"
    },
    {
      from_port   = 943
      to_port     = 943
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "OpenVPN Admin Web Interface"
    },
    {
      from_port   = 945
      to_port     = 945
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "OpenVPN Admin Web Interface (Alternative)"
    },
    {
      from_port   = 1194
      to_port     = 1194
      protocol    = "udp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "OpenVPN"
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
      security_groups = [module.alb_sg.security_group_id]
      description     = "Jenkins via ALB"
    },
    {
      from_port       = 3000
      to_port         = 3000
      protocol        = "tcp"
      security_groups = [module.alb_sg.security_group_id]
      description     = "Grafana via ALB from VPN"
    },
    {
      from_port       = 9090
      to_port         = 9090
      protocol        = "tcp"
      security_groups = [module.alb_sg.security_group_id]
      description     = "Prometheus via ALB from VPN"
    },
    {
      from_port       = 5601
      to_port         = 5601
      protocol        = "tcp"
      security_groups = [module.alb_sg.security_group_id]
      description     = "Kibana via ALB from VPN"
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

#---------------------------------------------------------------------------------------------------------------------
# IAM Role
#---------------------------------------------------------------------------------------------------------------------
module "management_iam" {
  source        = "../../common/module/iam_role"
  project_name  = local.project_name
  environment   = local.environment
  service_name  = "management"
  assume_role_service     = "ec2.amazonaws.com"
  instance_profile_enabled = true
  tags          = local.common_tags

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
          "arn:aws:s3:::s3-pumati-common-storage/*",
          "arn:aws:s3:::s3-pumati-tfstate",
          "arn:aws:s3:::s3-pumati-tfstate/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
        "secretsmanager:GetSecretValue"
      ]
      Resource = [
        "arn:aws:secretsmanager:ap-northeast-2:236450698266:secret:pumati-prod-frontend-.env*",
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