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
data "aws_acm_certificate" "v2_tebutebu" {
  domain      = "tebutebu.com"
  statuses    = ["ISSUED"]
  most_recent = true
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
data "terraform_remote_state" "network_test" {
  backend = "s3"
  config = {
    bucket = "s3-pumati-tfstate"
    key    = "aws/prod/network-test/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Security 모듈의 상태를 참조
data "terraform_remote_state" "security_test" {
  backend = "s3"
  config = {
    bucket = "s3-pumati-tfstate"
    key    = "aws/prod/security-test/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Compute 모듈의 상태를 참조
data "terraform_remote_state" "compute_test" {
  backend = "s3"
  config = {
    bucket = "s3-pumati-tfstate"
    key    = "aws/prod/compute-test/terraform.tfstate"
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
      
  # network-test 모듈 : vpc_id, public_subnet_id
  vpc_id_test       = data.terraform_remote_state.network_test.outputs.vpc_id
  public_subnet_ids_test = data.terraform_remote_state.network_test.outputs.public_subnet_ids
  service_subnet_ids_test = data.terraform_remote_state.network_test.outputs.service_subnet_ids
  db_subnet_ids_test = data.terraform_remote_state.network_test.outputs.db_subnet_ids

  # security-test 모듈 : 보안 그룹 정보
  alb_sg_id    = data.terraform_remote_state.security_test.outputs.alb_sg_id

  # compute-test 모듈 : 인스턴스 정보
  frontend_instance_id = data.terraform_remote_state.compute_test.outputs.frontend_instance_id
  backend_instance_id  = data.terraform_remote_state.compute_test.outputs.backend_instance_id
} 