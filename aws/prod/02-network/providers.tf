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
    bucket = "s3-terraform-pumati-v2"
    key    = "aws/prod/common/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Common 모듈의 출력 값 사용
locals {
  # common 모듈 : 프로젝트 이름, 리전, 환경, 공통 태그
  project_name = data.terraform_remote_state.common.outputs.project_name
  region       = data.terraform_remote_state.common.outputs.region
  environment  = data.terraform_remote_state.common.outputs.environment
  common_tags  = data.terraform_remote_state.common.outputs.common_tags
} 