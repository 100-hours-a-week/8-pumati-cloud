terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

data "terraform_remote_state" "common" {
  backend = "s3"
  config = {
    bucket = "pumati-s3-jacky"
    key    = "aws/dev/common/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

locals {
  project_name = data.terraform_remote_state.common.outputs.project_name
  region       = data.terraform_remote_state.common.outputs.region
  environment  = data.terraform_remote_state.common.outputs.environment
  domain_name  = data.terraform_remote_state.common.outputs.domain_name
  common_tags  = data.terraform_remote_state.common.outputs.common_tags
}

# base 모듈 상태 참조
data "terraform_remote_state" "base" {
  backend = "s3"
  config = {
    bucket = "pumati-s3-jacky"
    key    = "aws/dev/base/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "pumati-s3-jacky"
    key    = "aws/dev/network/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# AWS Secrets Manager에서 디스코드 웹훅 URL 가져오기
data "aws_secretsmanager_secret" "discord_webhooks" {
  name = "${local.project_name}-${local.environment}-discord-webhooks"
}

data "aws_secretsmanager_secret_version" "discord_webhooks" {
  secret_id = data.aws_secretsmanager_secret.discord_webhooks.id
}

locals {
  discord_webhooks = jsondecode(data.aws_secretsmanager_secret_version.discord_webhooks.secret_string)
}



# data "aws_secretsmanager_secret" "backend_env" {
#   name = "${local.project_name}-${local.environment}-backend-env"
# }

# data "aws_secretsmanager_secret_version" "backend_env" {
#   secret_id = data.aws_secretsmanager_secret.backend_env.id
# }

# locals {
#   backend_env_secret_name = data.aws_secretsmanager_secret_version.backend_env.secret_string
# }
