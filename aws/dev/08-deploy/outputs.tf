# 배포된 애플리케이션들의 정보 출력

output "pumati_namespace" {
  description = "Pumati 애플리케이션이 배포된 네임스페이스"
  value       = kubernetes_namespace.pumati.metadata[0].name
}

# output "backend_application_name" {
#   description = "ArgoCD에 배포된 백엔드 애플리케이션 이름"
#   value       = argocd_application.pumati_backend.metadata[0].name
# }

# output "frontend_application_name" {
#   description = "ArgoCD에 배포된 프론트엔드 애플리케이션 이름"
#   value       = argocd_application.pumati_frontend.metadata[0].name
# }

output "argocd_server_url" {
  description = "ArgoCD 서버 접속 URL"
  value       = "https://argocd.${local.domain_name}"
} 