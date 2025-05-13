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

# Common 모듈의 상태를 참조
data "terraform_remote_state" "common" {
  backend = "s3"
  config = {
    bucket = "s3-terraform-pumati"
    key    = "aws/prod/common/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Network 모듈의 상태를 참조 
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "s3-terraform-pumati"
    key    = "aws/prod/network/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

locals {
  project_name = data.terraform_remote_state.common.outputs.project_name
  region       = data.terraform_remote_state.common.outputs.region
  environment  = data.terraform_remote_state.common.outputs.environment
  common_tags  = data.terraform_remote_state.common.outputs.common_tags
  
  # Network 출력값
  vpc_id           = data.terraform_remote_state.network.outputs.vpc_id
  vpc_cidr         = data.terraform_remote_state.network.outputs.vpc_cidr
  public_subnet_id = data.terraform_remote_state.network.outputs.public_subnet_id
  
  # 보안 그룹 출력값 (security_group 모듈에서 참조)
  frontend_sg_id   = data.terraform_remote_state.network.outputs.frontend_sg_id
  backend_sg_id    = data.terraform_remote_state.network.outputs.backend_sg_id

} 