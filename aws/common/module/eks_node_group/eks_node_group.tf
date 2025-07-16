resource "aws_eks_node_group" "this" {
  node_group_name = "${var.project_name}-${var.environment}-${var.service_name}"

  cluster_name    = var.cluster_name
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids
  capacity_type   = var.capacity_type
  ami_type        = var.ami_type
  instance_types = var.instance_types

  # 노드 그룹 스케일링 설정
  scaling_config {
    desired_size = var.desired_size
    min_size     = var.min_size
    max_size     = var.max_size
  }

  # 업데이트 중 동시에 교체 가능한 노드 수
  dynamic "update_config" {
    for_each = var.max_unavailable != null ? [1] : []
    content {
      max_unavailable = var.max_unavailable
    }
  }

  remote_access {
    ec2_ssh_key               = var.ec2_ssh_key
    source_security_group_ids = var.remote_access_sg_ids
  }

  lifecycle {
    create_before_destroy = true
  }

  labels = var.labels  # 사용자 정의 Kubernetes 라벨

  # 태그 설정 (기본 태그 + Autoscaler 태그 조건부 포함)
  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-${var.service_name}"
    Component = "EKS-Worker-Nodes"
  }, var.enable_autoscaler_tags ? {
    "k8s.io/cluster-autoscaler/enabled" = "true"
    "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
  } : {})
}