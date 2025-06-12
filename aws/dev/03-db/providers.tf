terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "terraform_remote_state" "common" {
  backend = "s3"

  config = {
    bucket = "pumati-s3-jacky"
    key    = "terraform/dev/common/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

locals {
  project_name = data.terraform_remote_state.common.outputs.project_name
  domain_name  = data.terraform_remote_state.common.outputs.domain_name
  region       = data.terraform_remote_state.common.outputs.region
  environment  = data.terraform_remote_state.common.outputs.environment
  tfstate_bucket = data.terraform_remote_state.common.outputs.tfstate_bucket
  tfstate_region = data.terraform_remote_state.common.outputs.tfstate_region
  common_tags = data.terraform_remote_state.common.outputs.common_tags
}

provider "aws" {
  region = local.region

  default_tags {
    tags = local.common_tags
  }
}

# static 상태 참조 (S3 버킷 정보)
data "terraform_remote_state" "static" {
  backend = "s3"

  config = {
    bucket = "pumati-s3-jacky"
    key    = "terraform/dev/static/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# 네트워크 상태 참조
data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = "pumati-s3-jacky"
    key    = "terraform/dev/network/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

locals {
  s3_bucket_name = data.terraform_remote_state.static.outputs.db_backup_bucket_name
  vpc_id         = data.terraform_remote_state.network.outputs.vpc_id
  vpc_cidr_block = data.terraform_remote_state.network.outputs.vpc_cidr_block
  db_subnet_ids  = data.terraform_remote_state.network.outputs.db_subnet_ids
}

# DB 설정 변수들 (유지!)
locals {
  db_name                 = "tbdb"
  db_username             = "tbuser"
  db_password_secret_name = "${local.project_name}-${local.environment}-db-password"
}
