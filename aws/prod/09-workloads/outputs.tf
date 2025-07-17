#==============================================================================
# 09-workloads Outputs (Production)
#==============================================================================

#------------------------------------------------------------------------------
# Cluster Autoscaler 정보
#------------------------------------------------------------------------------
output "cluster_autoscaler_role_arn" {
  description = "Cluster Autoscaler IAM 역할의 ARN"
  value       = aws_iam_role.cluster_autoscaler_role.arn
}

output "cluster_autoscaler_role_name" {
  description = "Cluster Autoscaler IAM 역할의 이름"
  value       = aws_iam_role.cluster_autoscaler_role.name
}

#------------------------------------------------------------------------------
# AWS Load Balancer Controller 정보
#------------------------------------------------------------------------------
output "aws_load_balancer_controller_role_arn" {
  description = "AWS Load Balancer Controller IAM 역할의 ARN"
  value       = aws_iam_role.aws_load_balancer_controller_role.arn
}

output "aws_load_balancer_controller_role_name" {
  description = "AWS Load Balancer Controller IAM 역할의 이름"
  value       = aws_iam_role.aws_load_balancer_controller_role.name
}

#------------------------------------------------------------------------------
# External DNS 정보
#------------------------------------------------------------------------------
output "external_dns_role_arn" {
  description = "External DNS IAM 역할의 ARN"
  value       = aws_iam_role.external_dns_role.arn
}

output "external_dns_role_name" {
  description = "External DNS IAM 역할의 이름"
  value       = aws_iam_role.external_dns_role.name
}

#------------------------------------------------------------------------------
# 설치된 Helm Release 정보
#------------------------------------------------------------------------------
output "installed_helm_releases" {
  description = "설치된 Helm Release 목록"
  value = {
    cluster_autoscaler = {
      name      = helm_release.cluster_autoscaler.name
      namespace = helm_release.cluster_autoscaler.namespace
      version   = helm_release.cluster_autoscaler.version
      chart     = helm_release.cluster_autoscaler.chart
    }
    aws_load_balancer_controller = {
      name      = helm_release.aws_load_balancer_controller.name
      namespace = helm_release.aws_load_balancer_controller.namespace
      version   = helm_release.aws_load_balancer_controller.version
      chart     = helm_release.aws_load_balancer_controller.chart
    }
    external_dns = {
      name      = helm_release.external_dns.name
      namespace = helm_release.external_dns.namespace
      version   = helm_release.external_dns.version
      chart     = helm_release.external_dns.chart
    }
    metrics_server = {
      name      = helm_release.metrics_server.name
      namespace = helm_release.metrics_server.namespace
      version   = helm_release.metrics_server.version
      chart     = helm_release.metrics_server.chart
    }
  }
}

#------------------------------------------------------------------------------
# 클러스터 정보 (참조용)
#------------------------------------------------------------------------------
output "cluster_name" {
  description = "EKS 클러스터 이름"
  value       = local.cluster_name
}

output "cluster_endpoint" {
  description = "EKS 클러스터 엔드포인트"
  value       = local.cluster_endpoint
}

output "cluster_oidc_issuer_url" {
  description = "EKS 클러스터 OIDC Issuer URL"
  value       = local.cluster_oidc_issuer_url
}

#------------------------------------------------------------------------------
# 네트워크 정보 (참조용)
#------------------------------------------------------------------------------
output "vpc_id" {
  description = "VPC ID"
  value       = local.vpc_id
}

output "service_subnet_ids" {
  description = "서비스 서브넷 ID 목록"
  value       = local.service_subnet_ids
}

#------------------------------------------------------------------------------
# 워크로드 배포 상태
#------------------------------------------------------------------------------
output "workloads_deployment_status" {
  description = "워크로드 배포 상태 정보"
  value = {
    environment = local.environment
    project     = local.project_name
    region      = local.region
    
    # 설치된 컴포넌트 목록
    installed_components = [
      "Cluster Autoscaler", 
      "AWS Load Balancer Controller",
      "External DNS",
      "Metrics Server"
    ]
    
    # 제외된 컴포넌트 (dev와 차이점)
    excluded_components = [
      "AWS Node Termination Handler (온디멘드만 사용)",
      "Karpenter Controller",
      "Karpenter NodePool", 
      "Karpenter EC2NodeClass"
    ]
    
    # 아키텍처 특징
    architecture_notes = "단일 EKS 관리형 온디멘드 노드 그룹 사용, 스팟/Karpenter 미사용"
  }
}
