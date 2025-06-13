# EKS 클러스터 정보
output "cluster_name" {
  description = "EKS 클러스터 이름"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS 클러스터 엔드포인트"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_arn" {
  description = "EKS 클러스터 ARN"
  value       = aws_eks_cluster.main.arn
}

# ✅ 05-workloads에서 필요한 OIDC Issuer URL 추가
output "cluster_oidc_issuer_url" {
  description = "EKS 클러스터 OIDC Issuer URL (IRSA용)"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "cluster_security_group_id" {
  description = "EKS 클러스터 보안 그룹 ID"
  value       = aws_security_group.eks_cluster_sg.id
}

# 노드 관련 정보
output "node_security_group_id" {
  description = "EKS 노드 보안 그룹 ID"
  value       = aws_security_group.eks_node_sg.id
}

# ✅ 05-workloads에서 필요한 alias 추가
output "eks_node_security_group_id" {
  description = "EKS 노드 보안 그룹 ID (05-workloads 호환성용)"
  value       = aws_security_group.eks_node_sg.id
}

output "node_group_arn" {
  description = "EKS 노드 그룹 ARN"
  value       = aws_eks_node_group.system.arn
}

# IAM 역할 정보
output "cluster_iam_role_arn" {
  description = "EKS 클러스터 IAM 역할 ARN"
  value       = aws_iam_role.eks_cluster_role.arn
}

output "node_group_iam_role_arn" {
  description = "EKS 노드 그룹 IAM 역할 ARN"
  value       = aws_iam_role.eks_node_group_role.arn
}

# ✅ 05-workloads IRSA를 위한 OIDC Provider ARN (계산으로 생성)
output "oidc_provider_arn" {
  description = "EKS 클러스터 OIDC Provider ARN"
  value       = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}"
}

# ✅ Karpenter 태깅을 위한 클러스터 정보
output "cluster_primary_security_group_id" {
  description = "EKS 클러스터 기본 보안 그룹 ID"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}
