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
      version = "~> 2.11"
    }
    argocd = {
      source  = "argoproj-labs/argocd"
      version = "~> 5.0"
    }
  }
}

# 공통 데이터 참조
data "terraform_remote_state" "common" {
  backend = "s3"

  config = {
    bucket = "pumati-s3-jacky"
    key    = "terraform/dev/common/terraform.tfstate"
    region = "ap-northeast-2"
  }
}



# ArgoCD 상태 참조 (ArgoCD 서버 정보)
data "terraform_remote_state" "argocd" {
  backend = "s3"

  config = {
    bucket = "pumati-s3-jacky"
    key    = "terraform/dev/argocd/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# EKS 상태 참조
data "terraform_remote_state" "eks" {
  backend = "s3"

  config = {
    bucket = "pumati-s3-jacky"
    key    = "terraform/dev/eks/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# 네트워크 상태 참조
data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = "pumati-s3-jacky"
    key    = "terraform/dev/network/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

locals {
  # 기본 정보
  project_name = data.terraform_remote_state.common.outputs.project_name
  domain_name  = data.terraform_remote_state.common.outputs.domain_name
  region       = data.terraform_remote_state.common.outputs.region
  environment  = data.terraform_remote_state.common.outputs.environment
  common_tags  = data.terraform_remote_state.common.outputs.common_tags
  cluster_name = data.terraform_remote_state.eks.outputs.cluster_name
  
  # 네트워크 정보
  vpc_id               = data.terraform_remote_state.network.outputs.vpc_id
  private_subnet_ids   = data.terraform_remote_state.network.outputs.private_subnet_ids
  private_subnet_cidrs = data.terraform_remote_state.network.outputs.private_subnet_cidrs
  
  # Redis 태그
  redis_tags = merge(local.common_tags, {
    Component = "redis"
    Purpose   = "session-store"
  })
}

# AWS Provider 설정
provider "aws" {
  region = local.region

  default_tags {
    tags = local.common_tags
  }
}

# EKS 클러스터 정보
data "aws_eks_cluster" "main" {
  name = local.cluster_name
}

# EKS 클러스터 인증
data "aws_eks_cluster_auth" "main" {
  name = local.cluster_name
}



# Kubernetes Provider 설정
provider "kubernetes" {
  host                   = data.aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token
}

# Helm Provider 설정
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}