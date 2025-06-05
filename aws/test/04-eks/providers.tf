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
    key    = "terraform/test/common/terraform.tfstate"
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

# static 상태 참조
data "terraform_remote_state" "static" {
  backend = "s3"

  config = {
    bucket = "pumati-s3-jacky"
    key    = "terraform/test/static/terraform.tfstate"
    region = "ap-northeast-2"
  }
}


# 네트워크 상태 참조
data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = "pumati-s3-jacky"
    key    = "terraform/test/network/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

locals {
  # 네트워크 정보
  vpc_id               = data.terraform_remote_state.network.outputs.vpc_id
  vpc_cidr_block       = data.terraform_remote_state.network.outputs.vpc_cidr_block
  private_subnet_ids   = data.terraform_remote_state.network.outputs.private_subnet_ids
  public_subnet_ids    = data.terraform_remote_state.network.outputs.public_subnet_ids
  private_subnet_cidrs = data.terraform_remote_state.network.outputs.private_subnet_cidrs
  public_subnet_cidrs  = data.terraform_remote_state.network.outputs.public_subnet_cidrs
  db_subnet_cidrs      = data.terraform_remote_state.network.outputs.db_subnet_cidrs
}

# 03-db 상태 참조 (MySQL EC2 인스턴스 정보 가져오기)
data "terraform_remote_state" "db" {
  backend = "s3"

  config = {
    bucket = local.tfstate_bucket
    key    = "terraform/test/db/terraform.tfstate"
    region = local.tfstate_region
  }
}

# 네트워크 정보 로컬 변수
locals {
  # DB 정보
  mysql_security_group_id = data.terraform_remote_state.db.outputs.mysql_security_group_id
  mysql_private_ip        = data.terraform_remote_state.db.outputs.mysql_private_ip
}