#------------------------------------------------------------------------------
# 1. EKS 클러스터 SG
#------------------------------------------------------------------------------
# EKS 컨트롤 플레인(마스터 노드들)을 위한 보안 그룹
# AWS가 관리하는 Kubernetes API 서버들이 사용
module "eks_cluster_sg" {
  source        = "../../common/module/sg"

  project_name  = local.project_name
  environment   = local.environment
  tags          = local.common_tags

  service_name  = "eks-cluster"
  vpc_id        = local.vpc_id

  ingress_rules = [
    {
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = local.service_subnet_cidr_blocks
      description      = "Allow HTTPS from worker nodes to cluster API"
    }
  ]
}

#------------------------------------------------------------------------------
# 2. EKS 클러스터 IAM 
#------------------------------------------------------------------------------
# AmazonEKSClusterPolicy에 포함된 주요 권한들:
# - EC2 인스턴스 관리 (노드 그룹용)
# - VPC 네트워킹 설정
# - IAM 역할 관리
# - CloudWatch 로깅
# - Route53 DNS 관리 등

module "eks_cluster_role" {
  source                   = "../../common/module/iam_role"

  project_name             = local.project_name
  environment              = local.environment
  tags                     = local.common_tags

  service_name             = "eks-cluster"
  assume_role_service      = "eks.amazonaws.com"
  instance_profile_enabled = false

  enable_inline_policy  = false    
  enable_managed_policy = true   

  # AWS에서 제공하는 관리형 정책을 클러스터 역할에 연결 -> EKS가 클러스터를 관리하는데 필요한 모든 권한을 얻음
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  ]
}

#------------------------------------------------------------------------------
# 3. EKS 클러스터 생성
#------------------------------------------------------------------------------
# Amazon EKS 클러스터는 Kubernetes 컨트롤 플레인을 관리하는 서비스
# 여기서 생성되는 것은 마스터 노드들(API 서버, etcd, 스케줄러 등) -> 워커 노드는 별도로 생성해야 함

module "eks_cluster" {
  source        = "../../common/module/eks_cluster"

  project_name  = local.project_name                 
  environment   = local.environment     
  tags          = local.common_tags
                 
  service_name  = "eks-cluster"                    

  kubernetes_version = "1.31"                         # 클러스터 버전 1.31 

  cluster_role_arn = module.eks_cluster_role.role_arn # EKS에 연결된 IAM 역할 ARN
  cluster_security_group_id = module.eks_cluster_sg.security_group_id

  subnet_ids = local.service_subnet_ids

  endpoint_private_access = true                      # 내부 VPC에서도 접근 허용
  endpoint_public_access  = true                      # 퍼블릭 API 접근 허용
  public_access_cidrs     = ["0.0.0.0/0"]             # 전 IP 허용 (테스트용 / 운영에선 제한 필요)

  depends_on = [      
    module.eks_cluster_role
  ]
}

#------------------------------------------------------------------------------
# 4. EKS 워커 노드 SG
#------------------------------------------------------------------------------
# EKS 워커 노드(EC2 인스턴스들)를 위한 보안 그룹
# 애플리케이션 Pod들이 실행되는 노드들이 사용
module "eks_node_sg" {
  source        = "../../common/module/sg"

  project_name  = local.project_name
  environment   = local.environment
  tags          = local.common_tags

  service_name  = "eks-node"
  vpc_id        = local.vpc_id

  ingress_rules = [
    # EKS 워커 노드들끼리 모든 종류의 트래픽을 자유롭게 주고받을 수 있도록 허용
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      self        = true
      description = "All traffic between worker nodes"
    },
    {
      from_port                = 0
      to_port                  = 0
      protocol                 = "-1"
      source_security_group_id = module.eks_cluster_sg.security_group_id
      description              = "Allow traffic from EKS Control Plane to Worker Nodes"
    },
    # Prometheus가 Node Exporter(9100), Kubelet(10250) 메트릭 수집을 위해 접근
    {
      from_port   = 9100
      to_port     = 9100
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
      description = "Allow Prometheus to access Node Exporter (9100)"
    },
    {
      from_port   = 10250
      to_port     = 10250
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
      description = "Allow Prometheus to access Kubelet API (10250)"
    },
    # VPC 내의 모든 인스턴스(프론트, 백, 클러스터 등)가 이 노드에게 TCP 통신을 할 수 있게 허용
    {
      from_port   = 0
      to_port     = 65535
      protocol    = "tcp"
      cidr_blocks = [local.vpc_cidr_block]
      description = "Allow all TCP traffic from VPC"
    },
    # VPC 내의 모든 인스턴스(프론트, 백, 클러스터 등)가 이 노드에게 UDP 통신을 할 수 있게 허용
    {
      from_port   = 0
      to_port     = 65535
      protocol    = "udp"
      cidr_blocks = [local.vpc_cidr_block]
      description = "Allow all UDP traffic from VPC"
    }
  ]
}

#------------------------------------------------------------------------------
# 5. EKS 워커 노드 그룹 IAM 
#------------------------------------------------------------------------------
# 워커 노드(EC2 인스턴스)들이 사용할 IAM 역할
# 1. EKS : 노드가 EKS 클러스터에 조인하고 기본적인 Kubernetes 작업을 수행하는데 필요
# 2. CNI : Pod들 간의 네트워킹을 위해 VPC의 IP 주소를 관리하는 권한
# 3. ECR : 워커 노드가 ECR에서 컨테이너 이미지를 pull하기 위해 필요

module "eks_node_group_role" {
  source                   = "../../common/module/iam_role"

  project_name             = local.project_name
  environment              = local.environment
  tags                     = local.common_tags

  service_name             = "eks-node-group"
  assume_role_service      = "ec2.amazonaws.com"
  instance_profile_enabled = false

  enable_inline_policy  = false
  enable_managed_policy = true

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ]
}

#------------------------------------------------------------------------------
# 6. DB 인스턴스 보안 그룹에 EKS 노드 접근 규칙 추가
#------------------------------------------------------------------------------
# 애플리케이션 Pod들이 MySQL 데이터베이스에 연결할 수 있도록 함
resource "aws_security_group_rule" "mysql_from_eks_nodes" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = local.db_sg_id
  source_security_group_id = module.eks_node_sg.security_group_id
  description              = "DB access from EKS worker nodes"
}

#------------------------------------------------------------------------------
# 7. EKS system(관리형) 노드 그룹 생성
#------------------------------------------------------------------------------
# 시스템 컴포넌트(Karpenter, CoreDNS, ALB Controller 등)를 실행할 안정적인 노드 그룹
# 온디맨드 인스턴스를 사용하여 시스템 안정성 보장
module "eks_system_node_group" {
  source = "../../common/module/eks_node_group"

  project_name  = local.project_name
  environment   = local.environment
  tags          = local.common_tags 

  service_name  = "eks-system-node-group"

  cluster_name           = module.eks_cluster.cluster_name
  subnet_ids             = local.service_subnet_ids
  node_role_arn          = module.eks_node_group_role.role_arn
    
  capacity_type = "ON_DEMAND"
  ami_type      = "AL2_x86_64"
  instance_types = ["t3.small"]

  desired_size   = 1
  min_size       = 1
  max_size       = 3

  max_unavailable = 1

  ec2_ssh_key = "pumati-full-master"
  remote_access_sg_ids = [module.eks_node_sg.security_group_id]

  labels = {
    "node-type"     = "system"
    "capacity-type" = "on-demand"
    "role"          = "system-component"
  }

  enable_autoscaler_tags = false
}

#------------------------------------------------------------------------------
# 8. EKS Add-on 설치
#------------------------------------------------------------------------------
# VPC CNI : Pod들이 VPC IP 주소를 받아 서로 통신할 수 있도록 하는 핵심 컴포넌트
# CoreDNS : Kubernetes 클러스터 내부 DNS 서비스 Pod들이 서비스 이름으로 서로를 찾을 수 있도록 하는 DNS 해석 서비스
# kube-proxy : Service 라우팅 담당 Service로 들어오는 트래픽을 적절한 Pod로 전달하는 네트워크 프록시

# module "addon_vpc_cni" {
#   source = "../../common/module/eks_addons"
#   project_name  = local.project_name
#   environment   = local.environment
#   tags          = local.common_tags

#   service_name  = "eks-addon"
#   cluster_name = module.eks_cluster.cluster_name
#   addon_name   = "vpc-cni"

#   resolve_conflicts_on_create = "OVERWRITE"
#   resolve_conflicts_on_update = "OVERWRITE"

#   purpose       = "Pod Networking"
#   component     = "EKS-Networking"

#   depends_on = [
#     module.eks_system_node_group
#   ]
# }

# module "addon_coredns" {
#   source = "../../common/module/eks_addons"

#   project_name  = local.project_name
#   environment   = local.environment
#   tags          = local.common_tags

#   service_name  = "eks-addon"
#   cluster_name  = module.eks_cluster.cluster_name
#   addon_name    = "coredns"
#   addon_version = "v1.11.3-eksbuild.1"

#   resolve_conflicts_on_create = "OVERWRITE"
#   resolve_conflicts_on_update = "OVERWRITE"

#   purpose       = "Internal DNS Resolution"
#   component     = "EKS-DNS"

#   depends_on = [
#     module.addon_vpc_cni,
#     module.eks_system_node_group
#   ]
# }

# module "addon_kube_proxy" {
#   source = "../../common/module/eks_addons"

#   project_name  = local.project_name
#   environment   = local.environment
#   tags          = local.common_tags

#   service_name  = "eks-addon"
#   cluster_name = module.eks_cluster.cluster_name
#   addon_name   = "kube-proxy"

#   resolve_conflicts_on_create = "OVERWRITE"
#   resolve_conflicts_on_update = "OVERWRITE"

#   purpose       = "Service Traffic Routing"
#   component     = "EKS-Proxy"

#   depends_on = [
#     module.eks_system_node_group
#   ]
# }

# #------------------------------------------------------------------------------
# # 9. EKS OIDC Identity Provider 생성
# #------------------------------------------------------------------------------
# # OIDC (OpenID Connect)는 인증(Authenticate)을 위한 표준 프로토콜
# # EKS에서 사용하는 OIDC는 Kubernetes의 ServiceAccount와 AWS IAM을 연결하기 위해 사용 -> IRSA (IAM Roles for Service Accounts) 기능
# # 모든 Pod가 같은 권한을 공유하지 않도록 세밀한 권한 제어 가능 -> 워커 노드에서 실행되는 Pod들이 AWS 리소스에 접근할 때 필요 

# module "eks_oidc" {
#   source        = "../../common/module/eks_oidc"
#   project_name  = local.project_name
#   environment   = local.environment
#   tags          = local.common_tags

#   service_name  = "eks-oidc"
#   oidc_url      = module.eks_cluster.oidc_issuer_url

#   depends_on = [
#     module.eks_cluster
#   ]
# }

# #------------------------------------------------------------------------------
# # EBS CSI Driver를 위한 IAM 역할 생성
# #------------------------------------------------------------------------------
# # Amazon EBS Container Storage Interface Driver용 IAM 역할
# # Pod들이 EBS 볼륨을 영구 저장소로 사용할 수 있도록 하는 드라이버에 필요한 권한

# # 현재 AWS 계정 정보 가져오기 (IAM 역할 ARN에 필요)
# data "aws_caller_identity" "current" {}

# resource "aws_iam_role" "ebs_csi_driver_role" {
#   name = "${local.project_name}-${local.environment}-ebs-csi-driver-role"

#   # EKS의 Service Account가 이 역할을 assume할 수 있도록 설정
#   # IRSA (IAM Roles for Service Accounts) 패턴 사용
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}"
#         }
#         Action = "sts:AssumeRoleWithWebIdentity"
#         Condition = {
#           StringEquals = {
#             "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
#             "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
#           }
#         }
#       }
#     ]
#   })

#   tags = merge(
#     local.common_tags,
#     {
#       Name      = "${local.project_name}-${local.environment}-ebs-csi-driver-role"
#       Purpose   = "EBS Volume Management"
#       Component = "EKS-Storage"
#     }
#   )
# }

# #------------------------------------------------------------------------------
# # EBS CSI Driver에 필요한 AWS 관리형 정책 연결
# #------------------------------------------------------------------------------
# # EBS CSI Driver가 EBS 볼륨을 생성, 삭제, 연결, 분리하는데 필요한 권한
# resource "aws_iam_role_policy_attachment" "ebs_csi_driver_policy" {
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
#   role       = aws_iam_role.ebs_csi_driver_role.name
# }

# #------------------------------------------------------------------------------
# # EBS CSI Driver Add-on 설치
# #------------------------------------------------------------------------------
# # Amazon EBS Container Storage Interface Driver Add-on
# # 데이터베이스, 파일 저장 등에 필요한 영구 볼륨 지원
# resource "aws_eks_addon" "ebs_csi_driver" {
#   cluster_name = aws_eks_cluster.main.name
#   addon_name   = "aws-ebs-csi-driver"
  
#   # EBS CSI Driver가 사용할 Service Account의 IAM 역할 지정
#   service_account_role_arn = aws_iam_role.ebs_csi_driver_role.arn
  
#   resolve_conflicts_on_create = "OVERWRITE"
#   resolve_conflicts_on_update = "OVERWRITE"
  
#   # IAM 역할과 정책이 연결된 후 설치
#   depends_on = [
#     aws_iam_role_policy_attachment.ebs_csi_driver_policy,
#     aws_eks_node_group.system
#   ]

#   tags = merge(
#     local.common_tags,
#     {
#       Name      = "${local.project_name}-${local.environment}-ebs-csi-driver"
#       Purpose   = "Persistent Volume Support"
#       Component = "EKS-Storage"
#     }
#   )
# }

# #------------------------------------------------------------------------------
# # 22. EKS 관리형 노드와 Karpenter 노드 간 통신 허용
# #------------------------------------------------------------------------------
# # EKS가 시스템 노드 그룹에 자동 생성한 보안 그룹과 
# # Karpenter 노드가 사용하는 우리 보안 그룹 간의 통신 허용

# # 시스템 노드 → Karpenter 노드 (모든 트래픽)
# resource "aws_security_group_rule" "system_to_karpenter_all" {
#   type                     = "ingress"
#   from_port                = 0
#   to_port                  = 0
#   protocol                 = "-1"
#   source_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
#   security_group_id        = aws_security_group.eks_node_sg.id
#   description              = "All traffic from EKS managed system nodes to Karpenter nodes"
# }

# # Karpenter 노드 → 시스템 노드 (모든 트래픽)
# # 04에서 추가한 규칙임.
# # resource "aws_security_group_rule" "karpenter_to_system_all" {
# #   type                     = "ingress"
# #   from_port                = 0
# #   to_port                  = 0
# #   protocol                 = "-1"
# #   source_security_group_id = aws_security_group.eks_node_sg.id
# #   security_group_id        = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
# #   description              = "All traffic from Karpenter nodes to EKS managed system nodes"
# # }