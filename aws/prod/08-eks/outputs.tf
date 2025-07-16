# ----------------------------------------------------------------------------------------------------------------------
# EKS 클러스터 정보
# ----------------------------------------------------------------------------------------------------------------------
output "cluster_name" {
  description = "EKS 클러스터 이름"
  value       = module.eks_cluster.cluster_name
}

output "cluster_endpoint" {
  description = "EKS 클러스터 엔드포인트"
  value       = module.eks_cluster.cluster_endpoint
}

output "cluster_arn" {
  description = "EKS 클러스터 ARN"
  value       = module.eks_cluster.cluster_arn
}

# output "cluster_certificate_authority_data" {
#   description = "EKS 클러스터 인증서 데이터 (base64 인코딩)"
#   value       = module.eks_cluster.certificate_authority_data
# }

output "cluster_oidc_issuer_url" {
  description = "EKS 클러스터 OIDC Issuer URL (IRSA용)"
  value       = module.eks_cluster.oidc_issuer_url
}

output "cluster_version" {
  description = "EKS 클러스터 Kubernetes 버전"
  value       = "1.31"
}

# ----------------------------------------------------------------------------------------------------------------------
# 보안 그룹 정보
# ----------------------------------------------------------------------------------------------------------------------
output "cluster_security_group_id" {
  description = "EKS 클러스터 보안 그룹 ID"
  value       = module.eks_cluster_sg.security_group_id
}

output "node_security_group_id" {
  description = "EKS 워커 노드 보안 그룹 ID"
  value       = module.eks_node_sg.security_group_id
}

# 다른 모듈 호환성을 위한 별칭
output "eks_node_security_group_id" {
  description = "EKS 노드 보안 그룹 ID (호환성용)"
  value       = module.eks_node_sg.security_group_id
}

# ----------------------------------------------------------------------------------------------------------------------
# IAM 역할 정보
# ----------------------------------------------------------------------------------------------------------------------
output "cluster_iam_role_arn" {
  description = "EKS 클러스터 IAM 역할 ARN"
  value       = module.eks_cluster_role.role_arn
}

output "node_group_iam_role_arn" {
  description = "EKS 노드 그룹 IAM 역할 ARN"
  value       = module.eks_node_group_role.role_arn
}

output "ebs_csi_driver_iam_role_arn" {
  description = "EBS CSI Driver IAM 역할 ARN"
  value       = module.ebs_csi_driver_role.iam_role_arn
}

# ----------------------------------------------------------------------------------------------------------------------
# OIDC 관련 정보 (IRSA 설정용)
# ----------------------------------------------------------------------------------------------------------------------
output "oidc_provider_arn" {
  description = "EKS OIDC Identity Provider ARN (IRSA용)"
  value       = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(module.eks_cluster.oidc_issuer_url, "https://", "")}"
}

# ----------------------------------------------------------------------------------------------------------------------
# 네트워크 정보
# ----------------------------------------------------------------------------------------------------------------------
output "cluster_vpc_id" {
  description = "EKS 클러스터가 배포된 VPC ID"
  value       = local.vpc_id
}

output "cluster_subnet_ids" {
  description = "EKS 클러스터가 사용하는 서브넷 ID 목록"
  value       = local.service_subnet_ids
}
