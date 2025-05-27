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
    bucket = "s3-terraform-pumati"
    key    = "aws/dev/common/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

locals {
  project_name = data.terraform_remote_state.common.outputs.project_name
  region       = data.terraform_remote_state.common.outputs.region
  environment  = data.terraform_remote_state.common.outputs.environment
  common_tags  = data.terraform_remote_state.common.outputs.common_tags
}

# 네트워크 설정 데이터 가져오기
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "s3-terraform-pumati"
    key    = "aws/dev/network/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

locals {
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id
  subnet_id = data.terraform_remote_state.network.outputs.public_subnet_a_id
}

# 02-base 모듈에서 데이터베이스 암호 및 디스코드 웹훅 가져오기 s3 이름도
data "terraform_remote_state" "base" {
  backend = "s3"
  config = {
    bucket = "s3-terraform-pumati"
    key    = "aws/dev/base/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

locals {
  db_name     = "tbdb"
  db_username = "tbuser"
  db_password = data.terraform_remote_state.base.outputs.db_password
  s3_bucket_name = data.terraform_remote_state.base.outputs.app_storage_bucket_name
  
  # 스타트업 스크립트 템플릿 적용
  startup_script = templatefile("${path.module}/startup-script.sh", {
    project_name       = local.project_name
    environment        = local.environment
    db_password        = local.db_password
    db_name            = local.db_name
    db_username        = local.db_username
    s3_bucket_name     = local.s3_bucket_name
  })
}