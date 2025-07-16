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

# loadbalancer 모듈의 상태를 참조
data "terraform_remote_state" "loadbalancer" {
  backend = "s3"
  config = {
    bucket = "s3-pumati-tfstate"
    key    = "aws/shared/loadbalancer/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# loadbalancer 모듈의 출력 값 사용
locals {
  alb_dns_name = data.terraform_remote_state.loadbalancer.outputs.alb_dns_name
  alb_zone_id  = data.terraform_remote_state.loadbalancer.outputs.alb_zone_id
} 