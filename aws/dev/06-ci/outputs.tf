#==============================================================================
# 06-ci Outputs
#==============================================================================

# Jenkins 접속 정보
output "jenkins_url" {
  description = "Jenkins 웹 UI 접속 URL"
  value       = "https://jenkins.${local.domain_name}"
}

output "jenkins_internal_url" {
  description = "Jenkins 클러스터 내부 URL"
  value       = "http://${helm_release.jenkins.name}.${helm_release.jenkins.namespace}.svc.cluster.local:8080"
}

output "jenkins_port_forward_command" {
  description = "로컬 접속용 포트 포워딩 명령어"
  value       = "kubectl port-forward -n ${kubernetes_namespace.jenkins.metadata[0].name} svc/${helm_release.jenkins.name} 8080:8080"
}

output "jenkins_admin_username" {
  description = "Jenkins 관리자 사용자명"
  value       = "admin"
}

output "jenkins_admin_password" {
  description = "Jenkins 관리자 초기 비밀번호"
  value       = "admin123!"
  sensitive   = true
}

output "jenkins_namespace" {
  description = "Jenkins가 설치된 네임스페이스"
  value       = kubernetes_namespace.jenkins.metadata[0].name
}

# 스토리지 정보
output "jenkins_pv_name" {
  description = "Jenkins 마스터 PV명"
  value       = kubernetes_persistent_volume.jenkins_master.metadata[0].name
}

output "jenkins_pvc_name" {
  description = "Jenkins 마스터 PVC명"
  value       = kubernetes_persistent_volume_claim.jenkins_master.metadata[0].name
}

output "jenkins_ebs_volume_id" {
  description = "Jenkins에 연결된 EBS 볼륨 ID"
  value       = local.jenkins_ebs_volume_id
}

output "jenkins_ebs_availability_zone" {
  description = "Jenkins EBS 볼륨이 위치한 가용영역"
  value       = local.jenkins_ebs_availability_zone
}

# Helm 릴리스 정보
output "jenkins_helm_release" {
  description = "Jenkins Helm 릴리스 정보"
  value = {
    name      = helm_release.jenkins.name
    namespace = helm_release.jenkins.namespace
    version   = helm_release.jenkins.version
    status    = helm_release.jenkins.status
  }
}

# 서비스 정보
output "jenkins_service_name" {
  description = "Jenkins 서비스명"
  value       = "${helm_release.jenkins.name}"
}

output "jenkins_service_port" {
  description = "Jenkins 서비스 포트"
  value       = 8080
}

# 유용한 kubectl 명령어들
output "useful_commands" {
  description = "Jenkins 관리에 유용한 kubectl 명령어들"
  value = {
    # Jenkins 상태 확인
    check_jenkins_status = "kubectl get pods -n ${kubernetes_namespace.jenkins.metadata[0].name} -l app.kubernetes.io/name=jenkins"
    
    # Jenkins 로그 확인
    check_jenkins_logs = "kubectl logs -n ${kubernetes_namespace.jenkins.metadata[0].name} -l app.kubernetes.io/name=jenkins -f"
    
    # PV/PVC 상태 확인
    check_storage_status = "kubectl get pv,pvc -n ${kubernetes_namespace.jenkins.metadata[0].name}"
    
    # Jenkins 포트 포워딩 (로컬 테스트용)
    port_forward = "kubectl port-forward -n ${kubernetes_namespace.jenkins.metadata[0].name} svc/${helm_release.jenkins.name} 8080:8080"
    
    # Jenkins 에이전트 Pod 확인
    check_agents = "kubectl get pods -n ${kubernetes_namespace.jenkins.metadata[0].name} -l jenkins/label=jenkins-agent"
    
    # Ingress 상태 확인
    check_ingress = "kubectl get ingress -n ${kubernetes_namespace.jenkins.metadata[0].name}"
    
    # Jenkins 서비스 확인
    check_service = "kubectl get svc -n ${kubernetes_namespace.jenkins.metadata[0].name}"
  }
}

# 클러스터 역할 정보
output "jenkins_cluster_role" {
  description = "Jenkins 클러스터 역할 정보"
  value = {
    cluster_role_name = kubernetes_cluster_role.jenkins.metadata[0].name
    cluster_role_binding_name = kubernetes_cluster_role_binding.jenkins.metadata[0].name
  }
}

# 네트워크 정보
output "network_info" {
  description = "Jenkins 네트워크 관련 정보"
  value = {
    namespace = kubernetes_namespace.jenkins.metadata[0].name
    service_name = helm_release.jenkins.name
    internal_url = "http://${helm_release.jenkins.name}.${kubernetes_namespace.jenkins.metadata[0].name}.svc.cluster.local:8080"
    port_forward_command = "kubectl port-forward -n ${kubernetes_namespace.jenkins.metadata[0].name} svc/${helm_release.jenkins.name} 8080:8080"
  }
}

# 보안 정보
output "security_notes" {
  description = "Jenkins 보안 관련 중요 정보"
  value = {
    admin_password_note = "초기 관리자 비밀번호는 'admin123!'입니다. 반드시 첫 로그인 후 변경하세요."
    ebs_encryption_note = "EBS 볼륨은 AWS KMS로 암호화되어 저장됩니다."
    rbac_note = "Jenkins는 최소 권한 원칙에 따라 필요한 Kubernetes 리소스에만 접근할 수 있습니다."
    cluster_role = kubernetes_cluster_role.jenkins.metadata[0].name
  }
}
