output "frontend_ecr_url" {
  description = "Frontend ECR 리포지토리 URL"
  value       = module.frontend_ecr.repository_url
}

output "backend_ecr_url" {
  description = "Backend ECR 리포지토리 URL"
  value       = module.backend_ecr.repository_url
}
