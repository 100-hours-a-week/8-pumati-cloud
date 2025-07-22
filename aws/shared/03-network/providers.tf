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

data "terraform_remote_state" "prod_network" {
  backend = "s3"

  config = {
    bucket = "s3-pumati-tfstate"
    key    = "aws/prod/network/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

locals {
  # common 모듈 : 프로젝트 이름, 리전, 환경, 공통 태그
  project_name = data.terraform_remote_state.common.outputs.project_name
  region       = data.terraform_remote_state.common.outputs.region
  environment  = data.terraform_remote_state.common.outputs.environment
  common_tags  = data.terraform_remote_state.common.outputs.common_tags

  # prod 모듈 : route table 정보
  prod_network_public_route_table_id = data.terraform_remote_state.prod_network.outputs.public_route_table_ids[0]
  prod_network_service_route_table_id = data.terraform_remote_state.prod_network.outputs.service_route_table_ids[0]
  prod_network_db_route_table_id = data.terraform_remote_state.prod_network.outputs.db_route_table_ids[0]
}