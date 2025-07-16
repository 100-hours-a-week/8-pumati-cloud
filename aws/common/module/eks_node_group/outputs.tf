output "node_group_name" {
  description = "EKS 노드 그룹 이름"
  value = aws_eks_node_group.this.node_group_name
}

output "arn" {
  description = "EKS 노드 그룹 ARN"
  value = aws_eks_node_group.this.arn
}
