# common/terraform.tfvars - 공통 변수 값 설정
project_name = "pumati"
environment  = "shared"  # dev, staging, prod, test, shared 중 선택
region       = "ap-northeast-2"  # 서울 리전

# 공통 태그 설정
common_tags  = {
  "ManagedBy"  = "Terraform"
  "Project"    = "pumati"
  "Environment" = "shared"
  "Owner"       = "rowan" # 생성자에 맞게 변경 필요
}

# 상태 저장 관련 설정
tfstate_bucket = "s3-pumati-tfstate"  # 00-static에서 생성한 버킷
tfstate_region = "ap-northeast-2"  # 테라폼 상태 저장 버킷 리전 (서울)