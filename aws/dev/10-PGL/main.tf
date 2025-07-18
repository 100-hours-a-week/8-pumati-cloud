#==============================================================================
# PGL 스택 (Prometheus + Grafana + Loki) 
#==============================================================================

# 🎯 PGL 스택이 필요한 이유:
# 모니터링 및 관찰성: Kubernetes 클러스터와 애플리케이션의 메트릭, 로그, 시각화
# Prometheus: 메트릭 수집 및 저장 (시계열 데이터베이스)
# Grafana: 시각화 및 대시보드 (메트릭과 로그를 위한 통합 UI)
# 확장성: 대규모 클러스터 환경에서도 안정적인 모니터링 제공
# 알림: 메트릭 기반 알림 및 경고 시스템

#==============================================================================
# PGL 스택용 네임스페이스
#==============================================================================
# PGL 스택의 모든 컴포넌트가 격리된 환경에서 실행되도록 전용 네임스페이스 생성
resource "kubernetes_namespace" "pgl" {
  metadata {
    name = "pgl-system"

    labels = {
      name                          = "pgl-system"
      "app.kubernetes.io/name"      = "prometheus-grafana-stack"
      "app.kubernetes.io/component" = "monitoring"
      environment                   = local.environment
    }

    annotations = {
      "description" = "PGL 스택(Prometheus, Grafana, Loki)을 위한 네임스페이스"
      "created-by"  = "terraform"
      "team"        = "platform"
    }
  }
}

#==============================================================================
# Prometheus 공식 Helm 차트 배포 (기본 설정)
#==============================================================================
# kube-prometheus-stack은 Prometheus, Grafana, Alertmanager를 포함한 완전한 모니터링 솔루션
# 공식 prometheus-community 차트를 사용하여 최신 모범 사례를 따름
resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "65.1.1"
  namespace  = kubernetes_namespace.pgl.metadata[0].name

  depends_on = [kubernetes_namespace.pgl]
  timeout    = 1200

  # 기본 설정만 적용 (공식 문서 방식)
  values = [
    yamlencode({
      prometheus = {
        prometheusSpec = {
          retention = "7d"
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "gp2"
                accessModes = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "5Gi"
                  }
                }
              }
            }
          }
        }
      }

      grafana = {
        persistence = {
          enabled = true
          storageClassName = "gp2"
          size = "2Gi"
        }
        
        adminPassword = "pumati123"
        
        ingress = {
          enabled = true
          ingressClassName = "alb"
          annotations = {
            "alb.ingress.kubernetes.io/scheme" = "internet-facing"
            "alb.ingress.kubernetes.io/target-type" = "ip"
            "alb.ingress.kubernetes.io/certificate-arn" = "arn:aws:acm:ap-northeast-2:236450698266:certificate/63c6ca35-1946-4bd0-8057-b5fe5c656dd5"
            "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTPS\":443}]"
          }
          hosts = ["grafana.dev.tebutebu.com"]
          tls = [
            {
              secretName = "grafana-tls"
              hosts = ["grafana.dev.tebutebu.com"]
            }
          ]
        }
      }
    })
  ]
}

#==============================================================================
# Grafana 추가 대시보드 ConfigMap
#==============================================================================
# 사전 정의된 대시보드를 ConfigMap으로 생성하여 Grafana에서 자동 로딩
resource "kubernetes_config_map" "grafana_dashboards" {
  metadata {
    name      = "grafana-dashboards"
    namespace = kubernetes_namespace.pgl.metadata[0].name
    
    labels = {
      grafana_dashboard = "1"  # Grafana sidecar가 인식하는 레이블
    }
  }

  # Kubernetes 클러스터 대시보드
  data = {
    "kubernetes-cluster-overview.json" = jsonencode({
      dashboard = {
        id       = null
        title    = "Kubernetes Cluster Overview"
        tags     = ["kubernetes", "cluster"]
        timezone = "browser"
        panels   = [
          {
            title = "Cluster CPU Usage"
            type  = "stat"
            targets = [
              {
                expr = "100 - (avg(irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)"
              }
            ]
          }
        ]
        time = {
          from = "now-1h"
          to   = "now"
        }
        refresh = "30s"
      }
    })
    
    "prometheus-stats.json" = jsonencode({
      dashboard = {
        id       = null
        title    = "Prometheus Stats"
        tags     = ["prometheus"]
        timezone = "browser"
        panels   = [
          {
            title = "Prometheus Targets"
            type  = "stat"
            targets = [
              {
                expr = "prometheus_sd_discovered_targets"
              }
            ]
          }
        ]
        time = {
          from = "now-1h"
          to   = "now"
        }
        refresh = "30s"
      }
    })
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

#==============================================================================
# 백엔드 애플리케이션 ServiceMonitor
#==============================================================================
# Prometheus가 백엔드 애플리케이션의 메트릭을 자동으로 수집하도록 설정
resource "kubernetes_manifest" "pumati_backend_service_monitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "pumati-backend-metrics"
      namespace = "pgl-system"  # ✅ Prometheus와 같은 네임스페이스
      labels = {
        # ✅ kube-prometheus-stack이 인식할 수 있는 레이블
        release = "kube-prometheus-stack"
        app = "pumati-backend"
      }
    }
    spec = {
      # ✅ 다른 네임스페이스의 서비스도 모니터링 가능하도록 설정
      namespaceSelector = {
        matchNames = ["pumati"]
      }
      selector = {
        matchLabels = {
          # ✅ 실제 서비스 레이블과 일치
          "app.kubernetes.io/name" = "pumati-backend"
        }
      }
      endpoints = [
        {
          port = "http"  # ✅ 서비스 포트 이름과 일치
          path = "/actuator/prometheus"  # ✅ 메트릭 엔드포인트 경로
          interval = "30s"  # ✅ 수집 간격
          scrapeTimeout = "10s"  # ✅ 스크레이핑 타임아웃
        }
      ]
    }
  }

  depends_on = [helm_release.kube_prometheus_stack]
}
