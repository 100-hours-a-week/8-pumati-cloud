# common/terraform.tfvars - 공통 변수 값 설정

# GCP 프로젝트 관련 설정
project_name = "ktb8team"
project_id   = "ktb8team"  # 실제 GCP 프로젝트 ID로 변경 필요

# 환경 설정
environment  = "dev"  # dev, staging, prod 중 선택

# 리전 관련 설정 - L4 사용하기 가장 좋은 리전 선정
region       = "asia-east1"  # 타이완 리전
zone_suffix  = "a"  # a, b, c 등 존 접미사

# 공통 태그 설정 - aws와 다르게 gcp는 태그 이름이 모두 소문자여야 함
common_tags  = {
  "managed-by"  = "terraform"
  "project"     = "ktb8team"
  "environment" = "dev"
  "owner"       = "jacky"
}

# 도메인 관련 설정
domain_name  = "mydairy.my"  # 서비스 도메인

# 상태 저장 관련 설정
tfstate_bucket = "ktb8team-terraform-state"  # 테라폼 상태 저장 버킷
tfstate_region = "asia-northeast3"  # 테라폼 상태 저장 버킷 리전

# 네트워크 관련 설정
network_name = "ktb8team-network"