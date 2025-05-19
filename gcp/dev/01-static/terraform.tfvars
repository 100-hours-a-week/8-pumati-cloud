# terraform.tfvars - 변수 값 설정 파일

# 버킷 설정
bucket_name = "ktb8team-static-storage"
storage_class = "STANDARD"

# 버전 관리 설정
enable_versioning = true

# 보안 설정
uniform_bucket_level_access = true

# CORS 설정
cors_origins = ["*"]
cors_methods = ["GET", "POST", "PUT", "DELETE", "HEAD", "OPTIONS"]
cors_response_headers = ["*"]
cors_max_age_seconds = 3600

# 라벨 설정
additional_labels = {
  "purpose" = "static-storage"
}
managed_by = "terraform"