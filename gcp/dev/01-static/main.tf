# main.tf - GCS 스토리지 생성을 위한 메인 파일

# GCS 모듈 사용
module "gcs" {
  source = "../../common/modules/gcs"
  
  # 기본 설정
  project_id = local.project_id
  region     = local.region
  
  # 버킷 설정
  bucket_name = var.bucket_name
  storage_class = var.storage_class
  
  # 버전 관리 설정
  enable_versioning = var.enable_versioning
  
  # 보안 설정
  uniform_bucket_level_access = var.uniform_bucket_level_access
  
  # CORS 설정
  cors_origins = var.cors_origins
  cors_methods = var.cors_methods
  cors_response_headers = var.cors_response_headers
  cors_max_age_seconds = var.cors_max_age_seconds
  
  # 라벨 설정
  environment = local.environment
  common_tags = local.common_tags
  additional_labels = var.additional_labels
  managed_by = var.managed_by
}