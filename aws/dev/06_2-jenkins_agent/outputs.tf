#==============================================================================
# Jenkins 에이전트 출력 값
#==============================================================================

# 🔧 Jenkins 에이전트 배포 정보
output "jenkins_agent_info" {
  description = "Jenkins 에이전트 배포 정보"
  value = {
    # 네임스페이스 정보
    namespace = local.jenkins_namespace
    
    # 에이전트 정보
    agent_name     = local.jenkins_agent_name
    agent_replicas = local.jenkins_agent_replicas
    agent_labels   = local.jenkins_agent_labels
    use_websocket  = local.use_websocket
    
    # Deployment 정보
    deployment_name = kubernetes_deployment.jenkins_agent.metadata[0].name
    
    # Service 정보
    service_name = kubernetes_service.jenkins_agent.metadata[0].name
    service_port = 50000
    
    # ServiceAccount 정보
    service_account_name = kubernetes_service_account.jenkins_agent.metadata[0].name
    
    # ECR IAM 역할 정보
    ecr_role_arn = aws_iam_role.jenkins_agent_ecr_role.arn
  }
}

# 🔧 Jenkins 마스터 연결 정보
output "jenkins_connection_info" {
  description = "Jenkins 마스터 연결 정보"
  value = {
    jenkins_url    = local.jenkins_internal_url
    agent_workdir  = local.jenkins_workdir
    use_websocket  = local.use_websocket
    agent_labels   = local.jenkins_agent_labels
  }
}

# 🔧 ECR 접근 정보
output "ecr_access_info" {
  description = "ECR 접근 관련 정보"
  value = {
    iam_role_arn    = aws_iam_role.jenkins_agent_ecr_role.arn
    iam_policy_arn  = aws_iam_policy.jenkins_agent_build_policy.arn
    aws_account_id  = data.aws_caller_identity.current.account_id
    ecr_registry    = "${data.aws_caller_identity.current.account_id}.dkr.ecr.ap-northeast-2.amazonaws.com"
  }
}

# 🔧 컨테이너 설정 정보  
output "container_info" {
  description = "Jenkins 에이전트 컨테이너 정보"
  value = {
    jenkins_agent = {
      image = "${local.jenkins_agent_image.repository}:${local.jenkins_agent_image.tag}"
    }
    git = {
      image = "${local.git_image.repository}:${local.git_image.tag}"
    }
    aws_cli = {
      image = "${local.aws_cli_image.repository}:${local.aws_cli_image.tag}"
    }
    kaniko = {
      image = "${local.kaniko_image.repository}:${local.kaniko_image.tag}"
      config_secret = kubernetes_secret.kaniko_ecr_config.metadata[0].name
      mount_path = "/kaniko/.docker"
    }
  }
}

# 🔧 리소스 할당 정보
output "resource_allocation" {
  description = "Jenkins 에이전트 리소스 할당 정보"
  value = {
    jenkins_agent = local.jenkins_agent_resources
    git = local.git_resources
    aws_cli = local.aws_cli_resources
    kaniko = local.kaniko_resources
  }
}

# 🔧 배치 정보
output "deployment_placement" {
  description = "에이전트 배치 정보"
  value = {
    node_selector = local.node_selector
    tolerations   = local.tolerations
    affinity      = "스팟 인스턴스 선호"
  }
}

# 🔑 Secret 정보 (보안상 값은 노출하지 않음)
output "secrets_info" {
  description = "Secret 리소스 정보"
  value = {
    agent_secret = {
      name      = kubernetes_secret.jenkins_agent_secret.metadata[0].name
      namespace = kubernetes_secret.jenkins_agent_secret.metadata[0].namespace
    }
    kaniko_config = {
      name      = kubernetes_secret.kaniko_ecr_config.metadata[0].name
      namespace = kubernetes_secret.kaniko_ecr_config.metadata[0].namespace
    }
  }
  sensitive = false
}

# 🚀 배포 상태 및 다음 단계
output "deployment_status" {
  description = "Jenkins 에이전트 배포 상태 및 가이드"
  value = {
    status = "Jenkins 에이전트가 성공적으로 배포되었습니다"
    
    connection_method = "JNLP ${local.use_websocket ? "WebSocket" : "TCP"} 연결"
    
    verification_steps = [
      "1. Jenkins UI에서 노드 상태 확인: Jenkins 관리 → 노드 관리",
      "2. 에이전트 연결 상태 확인: ${local.jenkins_agent_name} 노드가 🟢 온라인 상태인지 확인",
      "3. Pod 상태 확인: kubectl get pods -n jenkins -l app.kubernetes.io/component=agent",
      "4. 로그 확인: kubectl logs -n jenkins -l app.kubernetes.io/component=agent"
    ]
    
    test_commands = [
      "# 에이전트 Pod 상태 확인",
      "kubectl get pods -n jenkins -l app.kubernetes.io/component=agent",
      "",
      "# 에이전트 로그 확인 (JNLP 연결)",
      "kubectl logs -n jenkins -l app.kubernetes.io/component=agent -c jenkins-agent",
      "",
      "# Kaniko 컨테이너 상태 확인", 
      "kubectl logs -n jenkins -l app.kubernetes.io/component=agent -c kaniko"
    ]
  }
} 