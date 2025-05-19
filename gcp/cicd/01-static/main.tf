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
  
  # resource_manager 등 다른 API 활성화에 영향을 주지 않도록 lifecycle 설정
  lifecycle {
    ignore_changes = [
      disable_dependent_services
    ]
  }
}

# Artifact Registry 모듈 사용 (API가 활성화된 후에 리소스 생성)
module "docker_registry" {
  source = "../../common/modules/artifact-registry"
  
  # 기본 설정
  project_id    = local.project_id
  location      = local.region
  repository_id = "ktb8team-docker-repo"
  description   = "Docker 이미지 저장소 - ktb8team"
  format        = "DOCKER"
  
  # 라벨 설정
  labels = {
    team        = "ktb8team"
    managed_by  = "terraform"
  }
  
  depends_on = [
    google_project_service.artifactregistry
  ]
}

# Jenkins 마스터용 영구 디스크 생성
module "jenkins_master_disk" {
  source = "../../common/modules/persistent-disk"
  
  # 기본 설정
  project_id  = local.project_id
  zone        = local.zone
  
  # 디스크 설정
  disk_name   = "jenkins-master-disk"
  description = "Jenkins 마스터 홈 디렉토리용 영구 디스크"
  disk_type   = "pd-balanced"  # 균형 잡힌 성능과 비용
  disk_size   = 20             # 20GB
  
  # 라벨 설정
  labels = {
    team        = "ktb8team"
    managed_by  = "terraform"
    service     = "jenkins"
    component   = "master"
  }
  
  # Compute Engine API가 활성화된 후에 디스크 생성
  depends_on = [
    google_project_service.compute
  ]
}

# Jenkins 에이전트용 영구 디스크 생성 (LLM 빌드용)
module "jenkins_agent_disk" {
  source = "../../common/modules/persistent-disk"
  
  # 기본 설정 (zonal 디스크 - 비용 효율적)
  project_id  = local.project_id
  zone        = local.zone  # zonal 디스크이므로 특정 존에 생성됨
  
  # 디스크 설정
  disk_name   = "jenkins-agent-disk"
  description = "Jenkins 에이전트용 영구 디스크 (LLM 빌드 최적화)"
  disk_type   = "pd-balanced"  # 비용 효율적인 디스크 타입
  disk_size   = 200            # 200GB (LLM 빌드에 충분한 공간)
  
  # common 라벨 사용하고 purpose만 추가
  labels = merge(local.common_labels, {
    "purpose" = "llm-build"
  })
  
  # Compute Engine API가 활성화된 후에 디스크 생성
  depends_on = [
    google_project_service.compute
  ]
}

# 디스코드 웹훅 URL 시크릿 생성
module "discord_webhook_secret" {
  source = "../../common/modules/secret-manager"
  
  # 프로젝트 설정
  project_id = local.project_id
  region     = local.region
  
  # 시크릿 설정
  secret_id   = "discord-webhook-url"
  secret_value = var.discord_webhook_url  # secrets.auto.tfvars에서 참조
  
  # 라벨 설정
  labels = local.common_labels
}

