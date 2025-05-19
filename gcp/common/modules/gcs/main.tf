# modules/gcs/main.tf - 스토리지(GCS) 모듈 정의

# GCS 버킷 생성
resource "google_storage_bucket" "bucket" {
  name          = var.bucket_name
  project       = var.project_id
  location      = var.region
  storage_class = var.storage_class
  
  # 버전 관리 설정
  versioning {
    enabled = var.enable_versioning
  }
  
  # 보안 설정
  uniform_bucket_level_access = var.uniform_bucket_level_access
  
  # CORS 설정
  cors {
    origin          = var.cors_origins
    method          = var.cors_methods
    response_header = var.cors_response_headers
    max_age_seconds = var.cors_max_age_seconds
  }
  
  # 라벨 설정 - common_tags와 추가 라벨 병합
  labels = merge(
    var.common_tags,
    {
      environment = lower(var.environment)
      managed_by  = lower(var.managed_by)
    },
    var.additional_labels
  )
} 