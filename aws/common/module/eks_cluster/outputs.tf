output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_arn" {
  description = "EKS 클러스터 ARN"
  value = aws_eks_cluster.this.arn
}

output "certificate_authority_data" {
  value = aws_eks_cluster.this.certificate_authority[0].data
}

output "oidc_issuer_url" {
  description = "EKS OIDC Provider URL"
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}
