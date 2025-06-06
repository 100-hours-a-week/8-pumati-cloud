# ArgoCD 관련 출력값들

# ArgoCD 서버 URL
output "argocd_server_url" {
  description = "ArgoCD 서버 접속 URL"
  value       = "https://argocd.${local.domain_name}"
}

# ArgoCD 네임스페이스
output "argocd_namespace" {
  description = "ArgoCD가 설치된 네임스페이스"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

# ArgoCD 서버 서비스 계정 ARN
output "argocd_server_role_arn" {
  description = "ArgoCD 서버 IAM 역할 ARN"
  value       = aws_iam_role.argocd_server.arn
}

# 프론트엔드 애플리케이션 URL
output "frontend_url" {
  description = "프론트엔드 애플리케이션 접속 URL"
  value       = "https://pumati.${local.domain_name}"
}

# 백엔드 API URL
output "backend_api_url" {
  description = "백엔드 API 접속 URL"
  value       = "https://api.${local.domain_name}"
}

# ArgoCD 초기 관리자 비밀번호 안내
output "argocd_admin_password_info" {
  description = "ArgoCD 초기 관리자 비밀번호 정보"
  value       = "초기 비밀번호는 'password'입니다. 로그인 후 반드시 변경하세요."
}

# Jenkins 웹훅 URL
output "jenkins_webhook_url" {
  description = "Jenkins에서 ArgoCD 동기화를 트리거하는 웹훅 URL"
  value       = "http://jenkins.${local.domain_name}/generic-webhook-trigger/invoke"
}

# Helm 차트 경로 정보
output "helm_charts_info" {
  description = "생성된 Helm 차트 경로 정보"
  value = {
    frontend = "aws/dev/07-argocd/helm/frontend"
    backend  = "aws/dev/07-argocd/helm/backend"
  }
}
