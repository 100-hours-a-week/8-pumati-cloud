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

# compute 모듈의 상태를 참조
data "terraform_remote_state" "compute" {
  backend = "s3"
  config = {
    bucket = "s3-terraform-pumati-v2"
    key    = "aws/prod/compute/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# compute 모듈의 출력 값 사용
locals {
  frontend_public_ip = data.terraform_remote_state.compute.outputs.frontend_public_ip 
} 