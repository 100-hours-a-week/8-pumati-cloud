#==============================================================================
# 06-2-jenkins_agent: Provider 설정
#==============================================================================

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

#==============================================================================
# 필요한 모듈들에서 정보 가져오기
#==============================================================================

# 00-common 모듈에서 기본 정보 가져오기
data "terraform_remote_state" "common" {
  backend = "s3"
  config = {
    bucket = "pumati-s3-jacky"
    key    = "terraform/dev/common/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# 04-eks 모듈에서 EKS 클러스터 정보 가져오기
data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "pumati-s3-jacky"
    key    = "terraform/dev/eks/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# 06_1-ci 모듈에서 Jenkins 정보 가져오기
data "terraform_remote_state" "jenkins_ci" {
  backend = "s3"
  config = {
    bucket = "pumati-s3-jacky"
    key    = "terraform/dev/ci/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# AWS 계정 정보
data "aws_caller_identity" "current" {}

#==============================================================================
# EKS 클러스터 데이터 소스 (Provider 설정을 위해 필요)
#==============================================================================
data "aws_eks_cluster" "cluster" {
  name = data.terraform_remote_state.eks.outputs.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = data.terraform_remote_state.eks.outputs.cluster_name
}

#==============================================================================
# Locals 설정 (06_1-ci에서 가져온 값들과 하드코딩 값들)
#==============================================================================
locals {
  # 🎯 기본 정보 (00-common에서 가져오기)
  project_name = data.terraform_remote_state.common.outputs.project_name
  environment  = data.terraform_remote_state.common.outputs.environment
  region       = data.terraform_remote_state.common.outputs.region

  # 🎯 EKS 정보 (04-eks에서 가져오기)
  cluster_oidc_issuer_url     = data.terraform_remote_state.eks.outputs.cluster_oidc_issuer_url
  cluster_oidc_provider_arn   = data.terraform_remote_state.eks.outputs.oidc_provider_arn

  # 🎯 Jenkins 정보 (06_1-ci에서 가져오기)
  jenkins_namespace    = data.terraform_remote_state.jenkins_ci.outputs.jenkins_namespace
  jenkins_internal_url = data.terraform_remote_state.jenkins_ci.outputs.jenkins_internal_url
  jenkins_service_name = data.terraform_remote_state.jenkins_ci.outputs.jenkins_service_name
  jenkins_service_port = data.terraform_remote_state.jenkins_ci.outputs.jenkins_service_port

  # 🔧 Jenkins 에이전트 설정 (하드코딩)
  jenkins_agent_name     = "agent"      # Jenkins UI에서 설정한 이름
  jenkins_agent_replicas = 1            # 에이전트 Pod 개수
  jenkins_workdir        = "/home/jenkins"  # Jenkins UI에서 설정한 작업 디렉토리
  use_websocket         = true          # WebSocket 연결 사용
  jenkins_agent_labels  = ["static"]   # Jenkins UI에서 설정한 라벨

  # 🐳 컨테이너 이미지 설정 (하드코딩)
  jenkins_agent_image = {
    repository = "jenkins/inbound-agent"
    tag        = "latest"
    pullPolicy = "IfNotPresent"
  }

  git_image = {
    repository = "alpine/git"
    tag        = "latest"
    pullPolicy = "Always"
  }

  aws_cli_image = {
    repository = "amazon/aws-cli"
    tag        = "latest"
    pullPolicy = "Always"
  }

  kaniko_image = {
    repository = "gcr.io/kaniko-project/executor"
    tag        = "debug"
    pullPolicy = "IfNotPresent"
  }

  # 🔧 리소스 설정 (하드코딩)
  jenkins_agent_resources = {
    requests = {
      cpu    = "500m"   # 0.5 CPU
      memory = "1Gi"    # 1GB RAM
    }
    limits = {
      cpu    = "2000m"  # 2 CPU
      memory = "4Gi"    # 4GB RAM
    }
  }

  git_resources = {
    requests = {
      cpu    = "100m"   # 0.1 CPU
      memory = "128Mi"  # 128MB RAM
    }
    limits = {
      cpu    = "500m"   # 0.5 CPU
      memory = "256Mi"  # 256MB RAM
    }
  }

  aws_cli_resources = {
    requests = {
      cpu    = "100m"   # 0.1 CPU
      memory = "128Mi"  # 128MB RAM
    }
    limits = {
      cpu    = "500m"   # 0.5 CPU
      memory = "256Mi"  # 256MB RAM
    }
  }

  kaniko_resources = {
    requests = {
      cpu    = "500m"   # 0.5 CPU
      memory = "1Gi"    # 1GB RAM
    }
    limits = {
      cpu    = "1000m"  # 1 CPU
      memory = "2Gi"    # 2GB RAM
    }
  }

  # 🔧 노드 배치 설정 (하드코딩)
  node_selector = {
    "node-type" = "system"
  }

  tolerations = [
    {
      key      = "node-type"
      operator = "Equal"
      value    = "system"
      effect   = "NoSchedule"
    }
  ]

  # 🏷️ 공통 태그 (00-common에서 가져와서 확장)
  common_tags = merge(
    data.terraform_remote_state.common.outputs.common_tags,
    {
      Component = "Jenkins-Agent"
    }
  )
}

#==============================================================================
# AWS Provider 설정
#==============================================================================
provider "aws" {
  region = data.terraform_remote_state.common.outputs.region

  default_tags {
    tags = data.terraform_remote_state.common.outputs.common_tags
  }
}

#==============================================================================
# Kubernetes Provider 설정
#==============================================================================
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

#==============================================================================
# Helm Provider 설정
#==============================================================================
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

#==============================================================================
# kubectl Provider 설정
#==============================================================================
provider "kubectl" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
} 