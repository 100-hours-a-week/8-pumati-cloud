# common/terraform.tfvars - 공통 변수 값 설정

# GCP 프로젝트 관련 설정
project_name = "ktb8team"
project_id   = "uplifted-might-460405-r3"  # 실제 GCP 프로젝트 ID로 변경 필요

# 환경 설정
environment  = "dev-vicky"  # dev, staging, prod 중 선택

# 리전 관련 설정 - 스팟이 안정적이고 싼 타이완
region       = "asia-east1"
zone_suffix  = "c"  # a, b, c 등 존 접미사

# 공통 태그 설정 (리스트로 변경) gcp 는 태그랑 라벨 다름. aws 의 태그가 라벨임  
common_tags = ["terraform", "ktb8team", "dev-vicky", "jacky"]

# 공통 라벨 설정 (키-값 맵 유지)
common_labels = {
  "managed-by"  = "terraform"
  "project"     = "ktb8team"
  "environment" = "dev-vicky"
  "owner"       = "jacky"
}

# 도메인 관련 설정
domain_name  = "dev-vicky.mydairy.my"  # 서비스 도메인

# 상태 저장 관련 설정
tfstate_bucket = "ktb8team-terraform-state"  # 테라폼 상태 저장 버킷(s3)
tfstate_region = "asia-northeast3"  # 테라폼 상태 저장 버킷 리전

# 네트워크 관련 설정
network_name = "ktb8team-network"