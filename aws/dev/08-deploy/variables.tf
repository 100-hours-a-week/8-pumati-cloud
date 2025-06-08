# ArgoCD admin 비밀번호
variable "argocd_admin_password" {
  description = "ArgoCD admin 사용자 비밀번호"
  type        = string
  sensitive   = true
} 