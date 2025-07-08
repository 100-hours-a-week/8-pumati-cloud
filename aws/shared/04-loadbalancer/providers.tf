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

# ACM 인증서 참조
data "aws_acm_certificate" "tebutebu" {
  domain      = "tebutebu.com"
  statuses    = ["ISSUED"]
  most_recent = true
}

# Common 모듈의 상태를 참조
data "terraform_remote_state" "common" {
  backend = "s3"
  config = {
    bucket = "s3-pumati-tfstate"
    key    = "aws/shared/common/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Network 모듈의 상태를 참조
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "s3-pumati-tfstate"
    key    = "aws/shared/network/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Security 모듈의 상태를 참조
data "terraform_remote_state" "security" {
  backend = "s3"
  config = {
    bucket = "s3-pumati-tfstate"
    key    = "aws/shared/security/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Common 모듈의 출력 값 사용
locals {
  # ACM 인증서 ARN (직접 입력)
  certificate_arn = "arn:aws:acm:ap-northeast-2:236450698266:certificate/802235a6-034f-43e9-b30b-319566f94059"

  # common 모듈 : 프로젝트 이름, 리전, 환경, 공통 태그
  project_name = data.terraform_remote_state.common.outputs.project_name
  region       = data.terraform_remote_state.common.outputs.region
  environment  = data.terraform_remote_state.common.outputs.environment
  common_tags  = data.terraform_remote_state.common.outputs.common_tags
      
  # network 모듈 : vpc_id, public_subnet_id
  vpc_id            = data.terraform_remote_state.network.outputs.vpc_id
  public_subnet_ids = data.terraform_remote_state.network.outputs.public_subnet_ids

  # security 모듈 : 보안 그룹 정보 (alb_sg_id 사용)
  alb_sg_id    = data.terraform_remote_state.security.outputs.alb_sg_id
}