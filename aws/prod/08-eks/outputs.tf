# ----------------------------------------------------------------------------------------------------------------------
# 1. EKS 클러스터 정보 출력
# ----------------------------------------------------------------------------------------------------------------------

output "eks_cluster_name" {
  value = module.eks_cluster.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks_cluster.cluster_endpoint
}

output "eks_cluster_certificate_authority_data" {
  value = module.eks_cluster.certificate_authority_data
}
