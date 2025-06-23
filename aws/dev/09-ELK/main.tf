#==============================================================================
# ELK 스택용 네임스페이스
#==============================================================================
# ELK 스택의 모든 컴포넌트가 격리된 환경에서 실행되도록 전용 네임스페이스 생성
resource "kubernetes_namespace" "elk" {
  metadata {
    name = "elk-system"

    labels = {
      name                          = "elk-system"
      "app.kubernetes.io/name"      = "elastic-stack"
      "app.kubernetes.io/component" = "logging"
      environment                   = local.environment
    }

    annotations = {
      "description" = "ELK 스택(Elasticsearch, Logstash, Kibana)을 위한 네임스페이스"
      "created-by"  = "terraform"
      "team"        = "platform"
    }
  }
}

#==============================================================================
# ELK RBAC 설정 (로그 수집 권한)
#==============================================================================
# ELK 서비스 계정
resource "kubernetes_service_account" "elk_service_account" {
  metadata {
    name      = "elk-service-account"
    namespace = kubernetes_namespace.elk.metadata[0].name
  }
}

# 클러스터 롤 (로그 수집 권한)
resource "kubernetes_cluster_role" "elk_cluster_role" {
  metadata {
    name = "elk-cluster-role"
  }
  
  rule {
    api_groups = [""]
    resources  = ["nodes", "pods", "services", "namespaces"]
    verbs      = ["get", "list", "watch"]
  }
}

# 클러스터 롤 바인딩
resource "kubernetes_cluster_role_binding" "elk_cluster_role_binding" {
  metadata {
    name = "elk-cluster-role-binding"
  }
  
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.elk_cluster_role.metadata[0].name
  }
  
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.elk_service_account.metadata[0].name
    namespace = kubernetes_namespace.elk.metadata[0].name
  }
}
