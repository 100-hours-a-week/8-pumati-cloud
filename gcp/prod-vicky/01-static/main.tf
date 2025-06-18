# main.tf - GCS 스토리지 생성을 위한 메인 파일
# Cloud Resource Manager API 활성화
resource "google_project_service" "resourcemanager" {
  project                    = local.project_id
  service                    = "cloudresourcemanager.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy         = false

  # 이미 활성화되어 있을 경우 오류 방지
  lifecycle {
    ignore_changes = [
      disable_dependent_services
    ]
  }
}

# Secret Manager API 활성화 (의존성 추가)
resource "google_project_service" "secretmanager" {
  project                    = local.project_id
  service                    = "secretmanager.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy         = false

  # 이미 활성화되어 있을 경우 오류 방지
  lifecycle {
    ignore_changes = [
      disable_dependent_services
    ]
  }

  # Resource Manager API가 먼저 활성화되도록 설정
  depends_on = [
    google_project_service.resourcemanager
  ]
}

# Compute Engine API 활성화 (의존성 추가)
resource "google_project_service" "compute" {
  project                    = local.project_id
  service                    = "compute.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy         = false

  # 이미 활성화되어 있을 경우 오류 방지
  lifecycle {
    ignore_changes = [
      disable_dependent_services
    ]
  }

  # Resource Manager API가 먼저 활성화되도록 설정
  depends_on = [
    google_project_service.resourcemanager
  ]
}

# Artifact Registry API 활성화
resource "google_project_service" "artifactregistry" {
  project                    = local.project_id
  service                    = "artifactregistry.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy         = false
}

# Cloud Scheduler API 활성화(03-scheduler 모듈 사용)
resource "google_project_service" "cloudscheduler" {
  project = local.project_id
  service = "cloudscheduler.googleapis.com"

  disable_dependent_services = false
  disable_on_destroy         = false
}
# Cloud Build API 활성화(03-scheduler 모듈 사용)
resource "google_project_service" "cloudbuild" {
  project            = local.project_id
  service            = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

# Artifact Registry 모듈 사용
module "docker_registry" {
  source = "../../common/modules/artifact-registry"

  # 기본 설정
  project_id    = local.project_id
  location      = local.region
  repository_id = "ktb8team-docker-repo-prod"
  description   = "Docker 이미지 저장소 - ktb8team"
  format        = "DOCKER"

  # 라벨 설정
  labels = local.common_labels

  # 의존성 추가
  depends_on = [
    google_project_service.artifactregistry
  ]
}

# # Cloudflare 터널 UUID 시크릿 생성
# module "cloudflare_tunnel_secret" {
#   source = "../../common/modules/secret-manager"

#   # 기본 설정
#   project_id   = local.project_id
#   region       = local.region
#   secret_id    = "cloudflare-tunnel-uuid"
#   secret_value = var.cloudflare_tunnel_uuid

#   # 라벨 설정
#   labels = local.common_tags

#   # API 활성화 후에 시크릿 생성
#   depends_on = [
#     google_project_service.secretmanager
#   ]
# }

# Discord 웹훅 URL 시크릿 생성
module "discord_webhook_secret" {
  source = "../../common/modules/secret-manager"

  # 기본 설정
  project_id   = local.project_id
  region       = local.region
  secret_id    = "discord-webhook-url"
  secret_value = var.discord_webhook_url

  # 라벨 설정
  labels = local.common_labels

  # API 활성화 후에 시크릿 생성
  depends_on = [
    google_project_service.secretmanager
  ]
}

# GitHub Actions 토큰 시크릿 생성
module "github_token_secret" {
  source = "../../common/modules/secret-manager"

  # 기본 설정
  project_id   = local.project_id
  region       = local.region
  secret_id    = "github-actions-token"
  secret_value = var.github_actions_token

  # 라벨 설정
  labels = local.common_labels

  # API 활성화 후에 시크릿 생성
  depends_on = [
    google_project_service.secretmanager
  ]
}

# 빌드 최적화를 위한 패키지/레이어 캐싱을 위한 PD 
module "persistent_disk" {
  source = "../../common/modules/persistent-disk"

  # 기본 설정 (zonal 디스크 - 비용 효율적)
  project_id = local.project_id
  zone       = local.zone # zonal 디스크이므로 특정 존에 생성됨

  # 디스크 설정
  disk_name   = "spot-persistent-disk"
  description = "Spot 인스턴스용 영구 디스크"
  disk_type   = "pd-balanced" # 비용 효율적인 디스크 타입
  disk_size   = 200           # 200GB (LLM 빌드에 충분한 공간)

  # common 라벨 사용하고 purpose만 추가
  labels = merge(local.common_labels, {
    "purpose" = "spot-llm-build"
  })

  # Compute Engine API가 활성화된 후에 디스크 생성
  depends_on = [
    google_project_service.compute
  ]
}

# Cloudflare 터널 JSON 시크릿 생성
module "cloudflare_tunnel_secret" {
  source = "../../common/modules/secret-manager"

  # 기본 설정
  project_id   = local.project_id
  region       = local.region
  secret_id    = "cloudflare-tunnel-uuid"
  secret_value = var.cloudflare_tunnel_uuid

  # 라벨 설정
  labels = local.common_labels

  # API 활성화 후에 시크릿 생성
  depends_on = [
    google_project_service.secretmanager
  ]
}

# Service Account 키 JSON 시크릿 생성
module "sa_key_secret" {
  source = "../../common/modules/secret-manager"

  # 기본 설정
  project_id   = local.project_id
  region       = local.region
  secret_id    = "service-account-key"
  secret_value = file("sa-key/ktb8team-458916-867527c8db5a.json") # 파일 경로만 지정

  # 라벨 설정
  labels = local.common_labels

  # API 활성화 후에 시크릿 생성
  depends_on = [
    google_project_service.secretmanager
  ]
}

# Discord 웹훅 URL 시크릿 생성 - AI 용
module "discord_webhook_secret_ai" {
  source = "../../common/modules/secret-manager"

  # 기본 설정
  project_id   = local.project_id
  region       = local.region
  secret_id    = "discord-webhook-url-ai"
  secret_value = var.discord_webhook_url_ai

  # 라벨 설정
  labels = local.common_labels

  # API 활성화 후에 시크릿 생성
  depends_on = [
    google_project_service.secretmanager
  ]
}

# Discord 웹훅 URL 전체방 용
module "discord_webhook_secret_all" {
  source = "../../common/modules/secret-manager"

  # 기본 설정
  project_id   = local.project_id
  region       = local.region
  secret_id    = "discord-webhook-url-all"
  secret_value = var.discord_webhook_url_all

  # 라벨 설정
  labels = local.common_labels

  # API 활성화 후에 시크릿 생성
  depends_on = [
    google_project_service.secretmanager
  ]
}
