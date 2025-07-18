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
# Elasticsearch 공식 Helm 차트 배포 (기본 설정)
#==============================================================================
resource "helm_release" "elasticsearch" {
  name       = "elasticsearch"
  repository = "https://helm.elastic.co"
  chart      = "elasticsearch"
  version    = "8.5.1"
  namespace  = kubernetes_namespace.elk.metadata[0].name

  depends_on = [kubernetes_namespace.elk]
  timeout    = 600

  values = [
    yamlencode({
      # 🎯 시스템 노드 배포 설정
      nodeSelector = {
        "node-type" = "system"
      }
      
      tolerations = [
        {
          key      = "node-type"
          operator = "Equal"
          value    = "system"
          effect   = "NoSchedule"
        }
      ]
      
      # 📊 클러스터 기본 설정 (원래대로)
      clusterName        = "elasticsearch"
      nodeGroup          = "master"
      replicas           = 1
      minimumMasterNodes = 1  # 원래 설정 복구
      
      # 🔧 리소스 설정 (그대로 유지)
      resources = {
        requests = {
          cpu    = "200m"
          memory = "512Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "1Gi"
        }
      }
      
      # 🔐 보안 설정 (그대로 유지)
      secret = {
        enabled  = true
        password = "pumati123"
      }
      
      # 🌐 프로토콜 설정 (HTTPS 활성화)
      protocol = "https"
      httpPort = 9200
      transportPort = 9300
      
      # 🔧 Pod 라이프사이클 설정 (안정적인 종료)
      lifecycle = {
        preStop = {
          exec = {
            command = ["/bin/sh", "-c", "sleep 20"]
          }
        }
      }
      
      # 📝 종료 타임아웃 설정
      terminationGracePeriodSeconds = 120
    })
  ]
}

#==============================================================================
# Kibana 공식 Helm 차트 배포 (기본 설정)
#==============================================================================
resource "helm_release" "kibana" {
  name       = "kibana"
  repository = "https://helm.elastic.co"
  chart      = "kibana"
  version    = "8.5.1"
  namespace  = kubernetes_namespace.elk.metadata[0].name

  depends_on = [helm_release.elasticsearch]
  timeout    = 600  # 15분 정도로 확대
  
  values = [
    yamlencode({
      # 🎯 시스템 노드 배포 설정
      nodeSelector = {
        "node-type" = "system"
      }
      
      tolerations = [
        {
          key      = "node-type"
          operator = "Equal"
          value    = "system"
          effect   = "NoSchedule"
        }
      ]
      
      # 📊 기본 설정
      replicas = 1
      
      # 🔧 리소스 설정 (백엔드 서버 1개 모니터링용으로 축소)
      resources = {
        requests = {
          cpu    = "200m"    # 500m → 200m으로 축소
          memory = "512Mi"   # 1Gi → 512Mi로 축소
        }
        limits = {
          cpu    = "500m"    # 1000m → 500m으로 축소
          memory = "1Gi"     # 2Gi → 1Gi로 축소
        }
      }
      
      # 🔗 Elasticsearch 연결
      elasticsearchHosts = "https://elasticsearch-master:9200"
      
      # 🔐 인증 정보
      elasticsearchCredentials = {
        username = "elastic"
        password = "pumati123"
      }

      # 🔒 SSL 설정 추가 (중요!)
      elasticsearchSSL = {
        verificationMode = "none"  # 인증서 검증 비활성화
      }
      
      createServiceAccount = true
      
      initContainers = {
        enabled = true
      }
      
      # 🔧 Helm Hook 설정 (destroy 문제 방지)
      lifecycle = {
        preStop = {
          exec = {
            command = ["/bin/sh", "-c", "sleep 10"]
          }
        }
      }
      
      # 🔒 SSL 설정 (헬름 차트가 자동으로 처리)
      # Kibana 8.x 헬름 차트는 자동으로 Elasticsearch 인증서를 설정함
      
      # 🌐 서비스 설정 (Ingress 사용)
      service = {
        type = "ClusterIP"
        port = 5601
      }
    })
  ]
}

#==============================================================================
# Kibana Ingress 설정 (kibana.dev.tebutebu.com)
#==============================================================================
resource "kubernetes_ingress_v1" "kibana" {
  metadata {
    name      = "kibana-ingress"
    namespace = kubernetes_namespace.elk.metadata[0].name
    
    annotations = {
      # AWS Load Balancer Controller 설정
      "kubernetes.io/ingress.class"                = "alb"
      "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"      = "ip"
      "alb.ingress.kubernetes.io/listen-ports"     = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
      "alb.ingress.kubernetes.io/certificate-arn"  = "arn:aws:acm:ap-northeast-2:236450698266:certificate/63c6ca35-1946-4bd0-8057-b5fe5c656dd5"
      "alb.ingress.kubernetes.io/ssl-redirect"     = "443"
      "alb.ingress.kubernetes.io/backend-protocol" = "HTTP"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/api/status"
      
      # 보안 헤더
      "alb.ingress.kubernetes.io/actions.ssl-redirect" = jsonencode({
        Type = "redirect"
        RedirectConfig = {
          Protocol   = "HTTPS"
          Port       = "443"
          StatusCode = "HTTP_301"
        }
      })
    }
    
    labels = merge(local.elk_tags, {
      "app.kubernetes.io/name"      = "kibana"
      "app.kubernetes.io/component" = "ingress"
    })
  }

  spec {
    rule {
      host = "kibana.dev.tebutebu.com"
      
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          
          backend {
            service {
              name = "kibana-kibana"
              port {
                number = 5601
              }
            }
          }
        }
      }
    }
    
    tls {
      hosts = ["kibana.dev.tebutebu.com"]
    }
  }

  depends_on = [helm_release.kibana]
}

#==============================================================================
# APM Server 공식 Helm 차트 배포 (개선된 보안 설정)
#==============================================================================
resource "helm_release" "apm_server" {
  name       = "apm-server"
  repository = "https://helm.elastic.co"
  chart      = "apm-server"
  version    = "8.5.1"
  namespace  = kubernetes_namespace.elk.metadata[0].name

  depends_on = [helm_release.elasticsearch, helm_release.kibana]
  timeout    = 600

  values = [
    yamlencode({
      # 🎯 시스템 노드 배포 설정
      nodeSelector = {
        "node-type" = "system"
      }
      
      tolerations = [
        {
          key      = "node-type"
          operator = "Equal"
          value    = "system"
          effect   = "NoSchedule"
        }
      ]
      
      # 📊 기본 설정
      replicas = 1
      
      # 🔧 리소스 설정
      resources = {
        requests = {
          cpu    = "100m"
          memory = "256Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }
      
      # 🔗 개선된 APM Server 설정 (SSL 검증 비활성화)
      apmConfig = {
        "apm-server.yml" = <<-EOF
          # APM 서버 기본 설정
          apm-server:
            host: "0.0.0.0:8200"
            
          # Elasticsearch 출력 설정 (SSL 검증 비활성화)
          output.elasticsearch:
            hosts: ["https://elasticsearch-master:9200"]
            username: "elastic"
            password: "$${ELASTICSEARCH_PASSWORD}"
            ssl:
              verification_mode: "none"  # 인증서 검증 비활성화
              
          # Kibana 연동 설정
          setup.kibana:
            host: "http://kibana-kibana:5601"
            
          # 로깅 설정
          logging:
            level: info
            to_stderr: true
            
          # APM 보안 설정
          apm-server.auth:
            secret_token: "$${APM_SECRET_TOKEN}"
        EOF
      }
      
      # 🔐 보안 강화 - 환경 변수 설정
      extraEnvs = [
        {
          name = "ELASTICSEARCH_PASSWORD"
          valueFrom = {
            secretKeyRef = {
              # Elasticsearch 8.x에서 자동 생성되는 실제 secret 이름
              name = "elasticsearch-master-credentials"
              key  = "password"
            }
          }
        },
        {
          name = "APM_SECRET_TOKEN"
          valueFrom = {
            secretKeyRef = {
              name = "apm-server-apm-token"
              key  = "secret-token"
            }
          }
        }
      ]
      
      # 🔧 Pod 라이프사이클 설정 (안정적인 종료)
      lifecycle = {
        preStop = {
          exec = {
            command = ["/bin/sh", "-c", "sleep 15"]
          }
        }
      }
      
      # 🔒 SSL 인증서 마운트 (보안 강화)
      extraVolumes = [
        {
          name = "elasticsearch-certs"
          secret = {
            secretName = "elasticsearch-master-certs"
          }
        }
      ]
      
      extraVolumeMounts = [
        {
          name      = "elasticsearch-certs"
          mountPath = "/usr/share/apm-server/config/certs"
          readOnly  = true
        }
      ]
      
      # 🌐 서비스 설정
      service = {
        type = "ClusterIP"
        ports = [
          {
            name       = "http"
            port       = 8200
            protocol   = "TCP"
            targetPort = 8200
          }
        ]
      }
    })
  ]
}

#==============================================================================
# APM Server Secret Token 생성
#==============================================================================
resource "kubernetes_secret" "apm_server_token" {
  metadata {
    name      = "apm-server-apm-token"
    namespace = kubernetes_namespace.elk.metadata[0].name
  }

  data = {
    secret-token = base64encode(random_password.apm_token.result)
  }

  type = "Opaque"
}
resource "random_password" "apm_token" {
  length  = 32
  special = true
}

