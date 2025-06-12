# 프로젝트 및 환경 설정
project_name = "pumati"
environment  = "prod"
region       = "ap-northeast-2"

# 공통 태그 설정
common_tags = {
  "ManagedBy"   = "Terraform"
  "Project"     = "pumati"
  "Environment" = "prod"
  "Owner"       = "rowan"
}

# Terraform 상태 저장 설정 (00-static에서 생성한 버킷)
tfstate_bucket = "s3-pumati-tfstate"
tfstate_region = "ap-northeast-2"
