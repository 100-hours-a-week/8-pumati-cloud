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

  # network 모듈 : vpc_id, subnet_ids
  vpc_id             = data.terraform_remote_state.network.outputs.vpc_id
  public_subnet_ids  = data.terraform_remote_state.network.outputs.public_subnet_ids
  service_subnet_ids = data.terraform_remote_state.network.outputs.service_subnet_ids
  db_subnet_ids      = data.terraform_remote_state.network.outputs.db_subnet_ids

  # security 모듈 : 보안 그룹 ID
  frontend_sg_id = data.terraform_remote_state.security.outputs.frontend_sg_id
  backend_sg_id  = data.terraform_remote_state.security.outputs.backend_sg_id
  db_sg_id       = data.terraform_remote_state.security.outputs.db_sg_id
  
  # loadbalancer 모듈 : ALB ARN
  alb_arn = data.terraform_remote_state.loadbalancer.outputs.alb_arn
  
  # compute 모듈 : 인스턴스 ID
  frontend_instance_id = data.terraform_remote_state.compute.outputs.frontend_instance_id
  backend_instance_id  = data.terraform_remote_state.compute.outputs.backend_instance_id
  db_instance_id       = data.terraform_remote_state.compute.outputs.db_instance_id
} 