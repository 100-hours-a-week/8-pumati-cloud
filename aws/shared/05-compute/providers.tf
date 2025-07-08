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
    bucket = "s3-pumati-tfstate"
    key    = "aws/shared/common/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = "s3-pumati-tfstate"
    key    = "aws/shared/network/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "security" {
  backend = "s3"

  config = {
    bucket = "s3-pumati-tfstate"
    key    = "aws/shared/security/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "loadbalancer" {
  backend = "s3"

  config = {
    bucket = "s3-pumati-tfstate"
    key    = "aws/shared/loadbalancer/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Common, Network, Security, Loadbalancer 모듈의 출력 값 사용
locals {
  # common 모듈 : 프로젝트 이름, 리전, 환경, 공통 태그
  project_name = data.terraform_remote_state.common.outputs.project_name
  region       = data.terraform_remote_state.common.outputs.region
  environment  = data.terraform_remote_state.common.outputs.environment
  common_tags  = data.terraform_remote_state.common.outputs.common_tags

  # network 모듈 : vpc_id
  vpc_id            = data.terraform_remote_state.network.outputs.vpc_id 
  public_subnet_ids = data.terraform_remote_state.network.outputs.public_subnet_ids[0]

  # security 모듈 : 보안 그룹 ID
  openvpn_sg_id = data.terraform_remote_state.security.outputs.openvpn_sg_id
  management_sg_id = data.terraform_remote_state.security.outputs.management_sg_id

  # security 모듈 : IAM 인스턴스 프로파일 이름
  management_instance_profile_name = data.terraform_remote_state.security.outputs.management_instance_profile_name

  # loadbalancer 모듈 : 타겟 그룹 ARN
  jenkins_target_group_arn    = data.terraform_remote_state.loadbalancer.outputs.target_group_arns["jenkins"]
  prometheus_target_group_arn = data.terraform_remote_state.loadbalancer.outputs.target_group_arns["prometheus"]
  grafana_target_group_arn    = data.terraform_remote_state.loadbalancer.outputs.target_group_arns["grafana"]
}

