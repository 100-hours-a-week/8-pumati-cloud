# common/terraform.tfvars - 공통 변수 값 설정

project_name = "ktb8team"
environment  = "dev"  # dev, staging, prod 중 선택
region       = "ap-northeast-2"  # 서울 리전

# 공통 태그 설정
common_tags  = {
  "ManagedBy"  = "Terraform"
  "Project"    = "ktb8team"
  "Environment" = "dev"
  "Owner"       = "jacky" # 생성자에 맞게 변경 필요
}

# 도메인 관련 설정
domain_name  = "tebutebu.com"  # 서비스 도메인

# 상태 저장 관련 설정
tfstate_bucket = "ktb8team-terraform-state"  # 테라폼 상태 저장 버킷
tfstate_region = "ap-northeast-2"  # 테라폼 상태 저장 버킷 리전 (서울)
