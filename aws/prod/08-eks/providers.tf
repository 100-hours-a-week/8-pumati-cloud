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

# 현재 AWS 계정 정보 가져오기 (IAM 역할 ARN에 필요)
data "aws_caller_identity" "current" {}

# Common 모듈의 상태를 참조
data "terraform_remote_state" "common" {
  backend = "s3"
  config = {
    bucket = "s3-pumati-tfstate"
    key    = "aws/prod/common/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Network 모듈의 상태를 참조
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "s3-pumati-tfstate"
    key    = "aws/prod/network/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Security 모듈의 상태를 참조
data "terraform_remote_state" "security" {
  backend = "s3"
  config = {
    bucket = "s3-pumati-tfstate"
    key    = "aws/prod/security/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Loadbalancer 모듈의 상태를 참조
data "terraform_remote_state" "loadbalancer" {
  backend = "s3"
  config = {
    bucket = "s3-pumati-tfstate"
    key    = "aws/prod/loadbalancer/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Compute 모듈의 상태를 참조
data "terraform_remote_state" "compute" {
  backend = "s3"
  config = {
    bucket = "s3-pumati-tfstate"
    key    = "aws/prod/compute/terraform.tfstate"
    region = "ap-northeast-2"
  }
}


# Common, Network, Security, Loadbalancer, Compute 모듈의 출력 값 사용
locals {
  # common 모듈 : 프로젝트 이름, 리전, 환경, 공통 태그
  project_name = data.terraform_remote_state.common.outputs.project_name
  region       = data.terraform_remote_state.common.outputs.region
  environment  = data.terraform_remote_state.common.outputs.environment
  common_tags  = data.terraform_remote_state.common.outputs.common_tags

  # network 모듈 :
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id
  vpc_cidr_block = data.terraform_remote_state.network.outputs.vpc_cidr

  public_subnet_ids = data.terraform_remote_state.network.outputs.public_subnet_ids
  
  service_subnet_ids = data.terraform_remote_state.network.outputs.service_subnet_ids
  service_subnet_cidr_blocks= data.terraform_remote_state.network.outputs.service_subnet_cidr_blocks

  # security 모듈 :
  db_sg_id = data.terraform_remote_state.security.outputs.db_sg_id

  # compute 모듈 :
  db_private_ip = data.terraform_remote_state.compute.outputs.db_private_ip
} 