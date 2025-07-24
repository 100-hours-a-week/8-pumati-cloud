# load-test-dev/05-domain/providers.tf
# 프로바이더 및 데이터 소스 설정

# ===============================
# Terraform 및 프로바이더 설정
# ===============================

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

# AWS 프로바이더 구성 (기본 - ap-northeast-2)
provider "aws" {
  region = "ap-northeast-2"
}

# AWS 프로바이더 구성 (us-east-1 - CloudFront용)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# ===============================
# 원격 상태 데이터 소스
# ===============================

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

# 컴퓨트 상태 참조 (03-compute에서 생성된 ALB 정보)
data "terraform_remote_state" "compute" {
  backend = "s3"
  config = {
    bucket = "8-ktb-chat-tfstate"
    key    = "terraform/load-test/compute/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# ===============================
# AWS 리소스 데이터 소스
# ===============================

# 가용 영역 정보
data "aws_availability_zones" "available" {
  state = "available"
}

# 기존 Route 53 호스팅 존 조회 (goorm-ktb-008.goorm.team)
data "aws_route53_zone" "main" {
  name         = "goorm-ktb-008.goorm.team"
  private_zone = false
}

# 백엔드 ALB 정보 조회 (CloudFront Origin용)
data "aws_lb" "backend_alb" {
  name = "${local.project_name}-${local.environment}-backend-alb"
}

# 기존 S3 버킷 정보 조회 (프론트엔드 정적 파일용)
data "aws_s3_bucket" "frontend" {
  bucket = "chat.goorm-ktb-008.goorm.team"
}

# 기존 ACM 인증서 조회 (CloudFront용 - us-east-1에 있어야 함)
data "aws_acm_certificate" "main" {
  domain   = "chat.goorm-ktb-008.goorm.team"
  statuses = ["ISSUED"]
  provider = aws.us_east_1  # CloudFront는 us-east-1 인증서만 사용 가능
}

# 기존 OAC (Origin Access Control) 조회
# CloudFront에서 S3 버킷에 안전하게 접근하기 위한 설정
data "aws_cloudfront_origin_access_control" "main" {
  id = "E3F0LVKDF0QVXE"
}

# ===============================
# 로컬 변수 정의
# ===============================

locals {
  # 공통 변수들
  project_name = data.terraform_remote_state.common.outputs.project_name
  domain_name  = data.terraform_remote_state.common.outputs.domain_name
  region       = data.terraform_remote_state.common.outputs.region
  environment  = data.terraform_remote_state.common.outputs.environment
  
  # 서브넷 정보 (Load Test는 퍼블릭 서브넷만 사용)
  public_subnets  = data.terraform_remote_state.network.outputs.public_subnet_ids
  
  # 가용 영역 분산
  availability_zones = data.aws_availability_zones.available.names
  
  # 공통 태그 (domain 모듈용으로 확장)
  common_tags = merge(
    data.terraform_remote_state.common.outputs.common_tags,
    {
      Module = "domain"
      Type   = "load-test"
    }
  )
} 