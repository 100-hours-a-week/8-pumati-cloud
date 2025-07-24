# load-test/02-mongoDB/providers.tf
# 프로바이더 및 데이터 소스 설정

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# 00-common 상태 참조
data "terraform_remote_state" "common" {
  backend = "s3"

  config = {
    bucket = "8-ktb-chat-tfstate"
    key    = "terraform/load-test/common/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# 네트워크 상태 참조 (02-network에서 생성된 VPC 정보)
data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = "8-ktb-chat-tfstate"
    key    = "terraform/load-test/network/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# 로컬 변수 정의
locals {
  project_name = data.terraform_remote_state.common.outputs.project_name
  domain_name  = data.terraform_remote_state.common.outputs.domain_name
  region       = data.terraform_remote_state.common.outputs.region
  environment  = data.terraform_remote_state.common.outputs.environment
  
  common_tags  = data.terraform_remote_state.common.outputs.common_tags
}

# AWS 프로바이더 설정
provider "aws" {
  region = local.region

  default_tags {
    tags = local.common_tags
  }
} 