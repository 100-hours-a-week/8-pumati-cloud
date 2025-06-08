# 애플리케이션용 네임스페이스 생성
resource "kubernetes_namespace" "pumati" {
  metadata {
    name = "pumati"
    
    labels = {
      name = "pumati"
      "app.kubernetes.io/name"      = "pumati"
      "app.kubernetes.io/component" = "pumati"
      "app.kubernetes.io/part-of"   = "pumati"
    }
  }
}

# ArgoCD Application - 백엔드 배포
resource "argocd_application" "pumati_backend" {
  metadata {
    name      = "pumati-backend"
    namespace = "argocd"  # ArgoCD 네임스페이스
    labels = {
      "app.kubernetes.io/name"      = "pumati-backend"
      "app.kubernetes.io/component" = "backend"
      "app.kubernetes.io/part-of"   = "pumati"
    }
  }

  spec {
    project = "default"

    # 소스 설정 - Git 저장소에서 Helm Chart를 가져옴
    source {
      repo_url        = "https://github.com/100-hours-a-week/8-pumati-cloud.git"
      target_revision = "jacky"                              # 브랜치명
      path            = "aws/dev/gitops/helm/backend"        # Helm Chart 경로

      # Helm 설정
      helm {
        value_files = [
          "values.yaml"
        ]
        # 추가 values 설정 (노드 셀렉터로 시스템 노드에 배포)
        values = yamlencode({
          nodeSelector = {
            "node-type" = "system"
          }
        })
      }
    }

    # 배포 대상 설정
    destination {
      server    = "https://kubernetes.default.svc"           # ArgoCD와 동일한 클러스터
      namespace = kubernetes_namespace.pumati.metadata[0].name  # pumati 네임스페이스
    }

    # 동기화 정책 설정
    sync_policy {
      # 자동 동기화 활성화
      automated {
        prune       = true   # 삭제된 리소스 정리
        self_heal   = true   # 변경사항 자동 복구
        allow_empty = false  # 빈 애플리케이션 허용 안함
      }
      
      # 동기화 옵션들
      sync_options = [
        "CreateNamespace=true",                    # 네임스페이스 자동 생성
        "PrunePropagationPolicy=foreground",       # 리소스 삭제 정책
        "PruneLast=true",                          # 마지막에 정리
        "ApplyOutOfSyncOnly=true"                  # 변경된 것만 적용
      ]
      
      # 재시도 정책
      retry {
        limit = 5              # 최대 5번 재시도
        backoff {
          duration     = "5s"  # 초기 대기 시간
          factor       = 2     # 대기 시간 증가 배수
          max_duration = "3m"  # 최대 대기 시간
        }
      }
    }
    
    # 차이점 무시 설정 (Deployment의 replicas 필드는 HPA가 관리하므로 무시)
    ignore_difference {
      group = "apps"
      kind  = "Deployment"
      json_pointers = [
        "/spec/replicas"
      ]
    }
  }

  # ArgoCD가 애플리케이션 생성을 완료할 때까지 기다리지 않음 (백그라운드 배포)
  wait = false

  # 종속성 설정 - pumati 네임스페이스가 생성된 후에 애플리케이션 배포
  depends_on = [
    kubernetes_namespace.pumati
  ]
}

# # ArgoCD Application - 프론트엔드 배포
# resource "argocd_application" "pumati_frontend" {
#   metadata {
#     name      = "pumati-frontend"
#     namespace = "argocd"  # ArgoCD 네임스페이스
#     labels = {
#       "app.kubernetes.io/name"      = "pumati-frontend"
#       "app.kubernetes.io/component" = "frontend"
#       "app.kubernetes.io/part-of"   = "pumati"
#     }
#   }

#   spec {
#     project = "default"

#     # 소스 설정 - Git 저장소에서 Helm Chart를 가져옴
#     source {
#       repo_url        = "https://github.com/100-hours-a-week/8-pumati-cloud.git"
#       target_revision = "jacky"                               # 브랜치명
#       path            = "aws/dev/gitops/helm/frontend"        # Helm Chart 경로

#       # Helm 설정
#       helm {
#         value_files = [
#           "values.yaml"
#         ]
#         # 추가 values 설정 (노드 셀렉터로 시스템 노드에 배포)
#         values = yamlencode({
#           nodeSelector = {
#             "node-type" = "system"
#           }
#         })
#       }
#     }

#     # 배포 대상 설정
#     destination {
#       server    = "https://kubernetes.default.svc"           # ArgoCD와 동일한 클러스터
#       namespace = kubernetes_namespace.pumati.metadata[0].name  # pumati 네임스페이스
#     }

#     # 동기화 정책 설정 (백엔드와 동일)
#     sync_policy {
#       automated {
#         prune     = true
#         self_heal = true
#       }
#       sync_options = [
#         "CreateNamespace=true",
#       ]
#     }
#   }

#   # 프론트엔드는 백엔드가 배포된 후에 배포
#   wait = true

#   depends_on = [
#     kubernetes_namespace.pumati,
#     argocd_application.pumati_backend
#   ]
# } 