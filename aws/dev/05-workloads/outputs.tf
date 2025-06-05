#==============================================================================
# 클러스터 접근 정보 (CI/CD, ArgoCD 설치용)
#==============================================================================

output "cluster_name" {
  description = "EKS 클러스터 이름"
  value       = local.cluster_name
}

output "cluster_endpoint" {
  description = "EKS 클러스터 API 엔드포인트"
  value       = local.cluster_endpoint
}

output "cluster_oidc_issuer_url" {
  description = "EKS 클러스터 OIDC Issuer URL (IRSA용)"
  value       = local.cluster_oidc_issuer_url
}

output "cluster_region" {
  description = "EKS 클러스터가 위치한 AWS 리전"
  value       = local.region
}

output "aws_account_id" {
  description = "AWS 계정 ID"
  value       = data.aws_caller_identity.current.account_id
}

#==============================================================================
# 네트워킹 정보 (ArgoCD ALB, 모니터링 Ingress용)
#==============================================================================

output "vpc_id" {
  description = "VPC ID"
  value       = local.vpc_id
}

output "private_subnet_ids" {
  description = "프라이빗 서브넷 ID 목록"
  value       = local.private_subnet_ids
}

output "public_subnet_ids" {
  description = "퍼블릭 서브넷 ID 목록 (ALB 배치용)"
  value       = data.terraform_remote_state.network.outputs.public_subnet_ids
}

output "eks_node_security_group_id" {
  description = "EKS 노드 보안 그룹 ID"
  value       = local.eks_node_sg_id
}

#==============================================================================
# 도메인 및 SSL 정보 (ArgoCD, 모니터링 HTTPS용)
#==============================================================================

output "domain_name" {
  description = "서비스 도메인 이름"
  value       = local.domain_name
}

output "acm_certificate_arn" {
  description = "ACM 와일드카드 SSL 인증서 ARN"
  value       = data.terraform_remote_state.static.outputs.acm_certificate_arn
}

#==============================================================================
# Karpenter 정보
#==============================================================================

output "karpenter_controller_role_arn" {
  description = "Karpenter Controller IAM 역할 ARN"
  value       = aws_iam_role.karpenter_controller_role.arn
}

output "karpenter_node_role_arn" {
  description = "Karpenter 노드 IAM 역할 ARN"
  value       = aws_iam_role.karpenter_node_role.arn
}

output "karpenter_node_instance_profile_name" {
  description = "Karpenter 노드 인스턴스 프로파일 이름"
  value       = aws_iam_instance_profile.karpenter_node_profile.name
}

output "karpenter_namespace" {
  description = "Karpenter 네임스페이스"
  value       = kubernetes_namespace.karpenter.metadata[0].name
}

output "karpenter_nodepool_name" {
  description = "Karpenter NodePool 이름"
  value       = kubectl_manifest.karpenter_nodepool.name
}

output "karpenter_ec2nodeclass_name" {
  description = "Karpenter EC2NodeClass 이름"
  value       = kubectl_manifest.karpenter_ec2nodeclass.name
}

#==============================================================================
# AWS Load Balancer Controller 정보 (ArgoCD Ingress용)
#==============================================================================

output "aws_load_balancer_controller_role_arn" {
  description = "AWS Load Balancer Controller IAM 역할 ARN"
  value       = aws_iam_role.aws_load_balancer_controller_role.arn
}

output "aws_load_balancer_controller_installed" {
  description = "AWS Load Balancer Controller 설치 상태"
  value       = true
}

#==============================================================================
# External DNS 정보 (ArgoCD 도메인 자동 관리용)
#==============================================================================

output "external_dns_role_arn" {
  description = "External DNS IAM 역할 ARN"
  value       = aws_iam_role.external_dns_role.arn
}

output "external_dns_installed" {
  description = "External DNS 설치 상태"
  value       = true
}

#==============================================================================
# Metrics Server 정보 (모니터링, HPA용)
#==============================================================================

output "metrics_server_installed" {
  description = "Metrics Server 설치 상태"
  value       = true
}

#==============================================================================
# ArgoCD 설치를 위한 통합 정보
#==============================================================================

output "argocd_ingress_annotations" {
  description = "ArgoCD Ingress에 사용할 공통 어노테이션"
  value = {
    "kubernetes.io/ingress.class"                     = "alb"
    "alb.ingress.kubernetes.io/scheme"                = "internet-facing"
    "alb.ingress.kubernetes.io/target-type"           = "ip"
    "alb.ingress.kubernetes.io/certificate-arn"       = data.terraform_remote_state.static.outputs.acm_certificate_arn
    "alb.ingress.kubernetes.io/ssl-redirect"          = "443"
    "alb.ingress.kubernetes.io/listen-ports"          = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
    "alb.ingress.kubernetes.io/subnets"               = join(",", data.terraform_remote_state.network.outputs.public_subnet_ids)
    "external-dns.alpha.kubernetes.io/hostname"       = "argocd.${local.domain_name}"
  }
}

output "monitoring_ingress_annotations" {
  description = "모니터링 도구(Grafana 등) Ingress에 사용할 공통 어노테이션"
  value = {
    "kubernetes.io/ingress.class"                     = "alb"
    "alb.ingress.kubernetes.io/scheme"                = "internet-facing"
    "alb.ingress.kubernetes.io/target-type"           = "ip"
    "alb.ingress.kubernetes.io/certificate-arn"       = data.terraform_remote_state.static.outputs.acm_certificate_arn
    "alb.ingress.kubernetes.io/ssl-redirect"          = "443"
    "alb.ingress.kubernetes.io/listen-ports"          = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
    "alb.ingress.kubernetes.io/subnets"               = join(",", data.terraform_remote_state.network.outputs.public_subnet_ids)
  }
}

#==============================================================================
# CI/CD를 위한 ECR 정보 (Docker 이미지 저장소)
#==============================================================================

output "ecr_repository_url_prefix" {
  description = "ECR 레지스트리 URL 접두사 (CI/CD 이미지 푸시용)"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${local.region}.amazonaws.com"
}

#==============================================================================
# kubectl 설정 명령어 (개발자용)
#==============================================================================

output "kubectl_config_command" {
  description = "kubectl 클러스터 접근 설정 명령어"
  value       = "aws eks update-kubeconfig --region ${local.region} --name ${local.cluster_name}"
}

#==============================================================================
# 유용한 확인 명령어들
#==============================================================================

output "useful_commands" {
  description = "클러스터 상태 확인용 유용한 명령어들"
  value = {
    "cluster_info"           = "kubectl cluster-info"
    "nodes_status"           = "kubectl get nodes -o wide"
    "karpenter_status"       = "kubectl get pods -n ${kubernetes_namespace.karpenter.metadata[0].name}"
    "metrics_server_status"  = "kubectl get pods -n kube-system | grep metrics-server"
    "resource_usage"         = "kubectl top nodes && kubectl top pods -A"
    "ingress_status"         = "kubectl get ingress -A"
    "alb_status"             = "kubectl get pods -n kube-system | grep aws-load-balancer-controller"
    "external_dns_status"    = "kubectl get pods -n kube-system | grep external-dns"
  }
}

#==============================================================================
# 환경 정보
#==============================================================================

output "environment_info" {
  description = "환경 정보 요약"
  value = {
    project_name = local.project_name
    environment  = local.environment
    region      = local.region
    domain_name = local.domain_name
    cluster_name = local.cluster_name
    vpc_id      = local.vpc_id
  }
}
