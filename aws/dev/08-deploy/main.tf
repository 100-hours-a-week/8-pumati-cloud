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

# 🚀 App of Apps 패턴 - 루트 애플리케이션 배포
# gitops/app-of-apps.yaml을 기반으로 모든 하위 애플리케이션들을 관리
resource "argocd_application" "app_of_apps" {
  metadata {
    name      = "app-of-apps-dev"
    namespace = "argocd"  # ArgoCD 네임스페이스
    labels = {
      "app.kubernetes.io/name"      = "app-of-apps"
      "app.kubernetes.io/component" = "root-application"
      "app.kubernetes.io/part-of"   = "pumati"
      "argocd.argoproj.io/managed-by" = "terraform"
    }
  }

  spec {
    project = "default"

    # 소스 설정 - gitops 폴더의 applications 디렉토리
    source {
      repo_url        = "https://github.com/100-hours-a-week/8-pumati-cloud.git"
      target_revision = "jacky"  # 현재 작업 브랜치
      path            = "aws/dev/gitops/applications"  # 하위 애플리케이션 정의 파일들 경로
    }

    # 배포 대상 설정
    destination {
      server    = "https://kubernetes.default.svc"  # ArgoCD와 동일한 클러스터
      namespace = "argocd"  # App of Apps는 ArgoCD 네임스페이스에 배포
    }

    # 🔧 동기화 정책 설정 (App of Apps에 특화)
    sync_policy {
      # 자동 동기화 활성화
      automated {
        prune       = true   # 삭제된 애플리케이션 정리
        self_heal   = true   # 변경사항 자동 복구
        allow_empty = false  # 빈 애플리케이션 허용 안함
      }
      
      # App of Apps에 필요한 동기화 옵션들
      sync_options = [
        "CreateNamespace=true",           # 네임스페이스 자동 생성
        "PrunePropagationPolicy=foreground", # 리소스 삭제 정책
        "PruneLast=true",                 # 마지막에 정리
        "ApplyOutOfSyncOnly=true",        # 변경된 것만 적용
        "ServerSideApply=true"            # 서버 사이드 적용 (충돌 방지)
      ]
      
      # 재시도 정책 (하위 애플리케이션들의 배포 실패 대비)
      retry {
        limit = 10             # App of Apps는 더 많은 재시도
        backoff {
          duration     = "10s" # 초기 대기 시간
          factor       = 2     # 대기 시간 증가 배수
          max_duration = "5m"  # 최대 대기 시간
        }
      }
    }
    
    # 🔧 하위 애플리케이션들의 차이점 무시 설정
    ignore_difference {
      group = "argoproj.io"
      kind  = "Application"
      json_pointers = [
        "/status"  # 애플리케이션 상태는 무시 (자동으로 변경됨)
      ]
    }
    
    # Helm Chart의 replicas 필드 무시 (HPA가 관리)
    ignore_difference {
      group = "apps"
      kind  = "Deployment"
      json_pointers = [
        "/spec/replicas"
      ]
    }
  }

  # App of Apps는 ArgoCD가 완전히 준비된 후에 배포
  wait = true

  # 종속성 설정
  depends_on = [
    kubernetes_namespace.pumati
  ]
}

# 🚀 App of Apps 패턴으로 관리되는 애플리케이션들
# 
# 📁 gitops/applications/ 디렉토리 구조:
# ├── backend-app.yaml     # 백엔드 애플리케이션 정의
# └── frontend-app.yaml    # 프론트엔드 애플리케이션 정의
# 
# 🔄 동작 방식:
# 1. app-of-apps-dev 애플리케이션이 gitops/applications/ 디렉토리를 모니터링
# 2. 해당 디렉토리의 YAML 파일들을 자동으로 ArgoCD에 등록
# 3. 각 애플리케이션은 독립적으로 배포 및 관리됨
# 4. Git에 푸시하면 자동으로 동기화됨
# 
# 💡 장점:
# - 중앙 집중식 애플리케이션 관리
# - 새로운 애플리케이션 추가 시 YAML 파일만 추가하면 됨
# - Terraform 코드 변경 없이 GitOps로 관리 가능 