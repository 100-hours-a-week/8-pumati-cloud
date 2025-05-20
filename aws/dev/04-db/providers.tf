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
    bucket = "s3-terraform-pumati"
    key    = "aws/dev/common/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

locals {
  project_name = data.terraform_remote_state.common.outputs.project_name
  region       = data.terraform_remote_state.common.outputs.region
  environment  = data.terraform_remote_state.common.outputs.environment
  common_tags  = data.terraform_remote_state.common.outputs.common_tags
}

# 네트워크 설정 데이터 가져오기
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "s3-terraform-pumati"
    key    = "aws/dev/network/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

locals {
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id
  subnet_id = data.terraform_remote_state.network.outputs.subnet_id
}