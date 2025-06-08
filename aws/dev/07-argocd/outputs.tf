# ArgoCD 관련 출력값들

# ArgoCD 접속 정보
output "argocd_server_url" {
  description = "ArgoCD 서버 접속 URL"
  value       = "https://argocd.${local.domain_name}"
}

output "argocd_admin_username" {
  description = "ArgoCD 관리자 사용자명"
  value       = "admin"
}

output "argocd_admin_password" {
  description = "ArgoCD 관리자 비밀번호"
  value       = "admin123!"
  sensitive   = true  # 민감 정보로 표시
}

# ArgoCD 네임스페이스 정보
output "argocd_namespace" {
  description = "ArgoCD가 설치된 네임스페이스"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

# ArgoCD 서비스 계정 정보
output "argocd_server_service_account_name" {
  description = "ArgoCD 서버 서비스 계정 이름"
  value       = kubernetes_service_account.argocd_server.metadata[0].name
}

output "argocd_controller_service_account_name" {
  description = "ArgoCD 컨트롤러 서비스 계정 이름"
  value       = kubernetes_service_account.argocd_application_controller.metadata[0].name
}

output "argocd_repo_server_service_account_name" {
  description = "ArgoCD 저장소 서버 서비스 계정 이름"
  value       = kubernetes_service_account.argocd_repo_server.metadata[0].name
}

# ArgoCD IAM 역할 정보
output "argocd_server_iam_role_arn" {
  description = "ArgoCD 서버 IAM 역할 ARN"
  value       = aws_iam_role.argocd_server.arn
}

output "argocd_controller_iam_role_arn" {
  description = "ArgoCD 컨트롤러 IAM 역할 ARN"
  value       = aws_iam_role.argocd_controller.arn
}

output "argocd_repo_server_iam_role_arn" {
  description = "ArgoCD 저장소 서버 IAM 역할 ARN"
  value       = aws_iam_role.argocd_repo_server.arn
}

# ArgoCD 볼륨 정보
output "argocd_pv_name" {
  description = "ArgoCD 서버 PersistentVolume 이름"
  value       = kubernetes_persistent_volume.argocd_server.metadata[0].name
}

output "argocd_pvc_name" {
  description = "ArgoCD 서버 PersistentVolumeClaim 이름"
  value       = kubernetes_persistent_volume_claim.argocd_server.metadata[0].name
}

output "argocd_ebs_volume_id" {
  description = "ArgoCD 서버가 사용하는 EBS 볼륨 ID"
  value       = data.terraform_remote_state.static.outputs.argocd_server_ebs_volume_id
}

# ArgoCD 접속 안내
output "argocd_access_info" {
  description = "ArgoCD 접속 정보 종합"
  value = {
    url      = "https://argocd.${local.domain_name}"
    username = "admin"
    password = "admin123!"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }
  sensitive = true  # 비밀번호 포함으로 민감 정보 처리
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
