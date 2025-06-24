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
      cidr_blocks = ["211.244.225.166/32", "0.0.0.0/0"]
      description = "SSH"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["211.244.225.166/32", "0.0.0.0/0"]
      description = "HTTPS"
    },
    {
      from_port   = 943
      to_port     = 943
      protocol    = "tcp"
      cidr_blocks = ["211.244.225.166/32", "0.0.0.0/0"]
      description = "OpenVPN Admin Web Interface"
    },
    {
      from_port   = 945
      to_port     = 945
      protocol    = "tcp"
      cidr_blocks = ["211.244.225.166/32", "0.0.0.0/0"]
      description = "OpenVPN Admin Web Interface (Alternative)"
    },
    {
      from_port   = 1194
      to_port     = 1194
      protocol    = "udp"
      cidr_blocks = ["211.244.225.166/32", "0.0.0.0/0"]
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
      cidr_blocks = ["211.244.225.166/32", "0.0.0.0/0"]
      description = "SSH"
    },
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = ["211.244.225.166/32", "0.0.0.0/0"]
      description = "Management UI"
    },
    {
      from_port   = 50000
      to_port     = 50000
      protocol    = "tcp"
      cidr_blocks = ["211.244.225.166/32", "0.0.0.0/0"]
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
        "arn:aws:secretsmanager:ap-northeast-2:236450698266:secret:pumati-prod-frontend-test-.env*",
        "arn:aws:secretsmanager:ap-northeast-2:236450698266:secret:pumati-prod-backend-test-.env*"
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