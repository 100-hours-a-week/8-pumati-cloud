terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

data "terraform_remote_state" "common" {
  backend = "s3"

  config = {
    bucket = "pumati-s3-jacky"
    key    = "terraform/test/common/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

locals {
  project_name = data.terraform_remote_state.common.outputs.project_name
  domain_name  = data.terraform_remote_state.common.outputs.domain_name
  region       = data.terraform_remote_state.common.outputs.region
  environment  = data.terraform_remote_state.common.outputs.environment
  tfstate_bucket = data.terraform_remote_state.common.outputs.tfstate_bucket
  tfstate_region = data.terraform_remote_state.common.outputs.tfstate_region
  common_tags = data.terraform_remote_state.common.outputs.common_tags
}

provider "aws" {
  region = local.region

  default_tags {
    tags = local.common_tags
  }
}

# static 상태 참조
data "terraform_remote_state" "static" {
  backend = "s3"

  config = {
    bucket = "pumati-s3-jacky"
    key    = "terraform/test/static/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# 네트워크 상태 참조
data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = "pumati-s3-jacky"
    key    = "terraform/test/network/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# 03-db 상태 참조 (MySQL EC2 인스턴스 정보 가져오기)
data "terraform_remote_state" "db" {
  backend = "s3"

  config = {
    bucket = local.tfstate_bucket
    key    = "terraform/test/db/terraform.tfstate"
    region = local.tfstate_region
  }
}

#04-eks 상태 참조
data "terraform_remote_state" "eks" {
  backend = "s3"

  config = {
    bucket = local.tfstate_bucket
    key    = "terraform/test/eks/terraform.tfstate"
    region = local.tfstate_region
  }
}

# EKS 클러스터 정보
locals {
  cluster_name = data.terraform_remote_state.eks.outputs.cluster_name
  cluster_endpoint = data.terraform_remote_state.eks.outputs.cluster_endpoint
  cluster_oidc_issuer_url = data.terraform_remote_state.eks.outputs.cluster_oidc_issuer_url
  
  # 네트워크 정보 (04-eks와 동일한 VPC/서브넷 사용)
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
  
  # 보안 그룹 정보
  eks_node_sg_id = data.terraform_remote_state.eks.outputs.eks_node_security_group_id
}

# AWS 계정 정보 (IAM 역할 ARN 구성에 필요)
data "aws_caller_identity" "current" {}

# EKS 클러스터 세부 정보
data "aws_eks_cluster" "main" {
  name = local.cluster_name
}

# Kubernetes provider 설정을 위한 인증 토큰
data "aws_eks_cluster_auth" "main" {
  name = local.cluster_name
}

# Kubernetes provider 설정
provider "kubernetes" {
  host                   = data.aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token
}

# Helm provider 설정
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}

# 🎯 kubectl provider 설정 추가
provider "kubectl" {
  host                   = data.aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token
  load_config_file       = false
}