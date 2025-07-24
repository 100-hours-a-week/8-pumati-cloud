# load-test/02-mongoDB/providers.tf
# 프로바이더 및 데이터 소스 설정

# AWS 프로바이더 설정
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

# AWS 프로바이더 구성
provider "aws" {
  region = "ap-northeast-2"
}

# 00-common 상태 참조 (공통 변수)
data "terraform_remote_state" "common" {
  backend = "s3"

  config = {
    bucket = "8-ktb-chat-tfstate"
    key    = "terraform/load-test/common/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# 네트워크 상태 참조 (01-network에서 생성된 VPC 정보)
data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = "8-ktb-chat-tfstate"
    key    = "terraform/load-test/network/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# 몽고DB 상태 참조 (02-mongoDB에서 생성된 MongoDB 정보)
data "terraform_remote_state" "mongodb" {
  backend = "s3"

  config = {
    bucket = "8-ktb-chat-tfstate"
    key    = "terraform/load-test/mongodb/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# 가용 영역 정보
data "aws_availability_zones" "available" {
  state = "available"
}

# 로컬 변수 정의
locals {
  project_name = data.terraform_remote_state.common.outputs.project_name
  domain_name  = data.terraform_remote_state.common.outputs.domain_name
  region       = data.terraform_remote_state.common.outputs.region
  environment  = data.terraform_remote_state.common.outputs.environment
  
  # 서브넷 정보 (Load Test는 퍼블릭 서브넷만 사용)
  public_subnets  = data.terraform_remote_state.network.outputs.public_subnet_ids
  
  # 가용 영역 분산
  availability_zones = data.aws_availability_zones.available.names
  
  # 공통 태그 (compute 모듈용으로 확장)
  common_tags = merge(
    data.terraform_remote_state.common.outputs.common_tags,
    {
      Module = "compute"
      Type   = "load-test"
    }
  )
} 