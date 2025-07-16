output "addon_name" {
  value       = aws_eks_addon.this.addon_name
  description = "EKS Add-on 이름"
}

output "addon_arn" {
  value       = aws_eks_addon.this.arn
  description = "EKS Add-on ARN"
}