# variables.tf - 변수 정의 파일



# 버킷 관련 변수
variable "bucket_name" {
  description = "GCS 버킷 이름 (전역적으로 고유해야 함)"
  type        = string
}

variable "storage_class" {
  description = "스토리지 클래스 (예: STANDARD, NEARLINE, COLDLINE, ARCHIVE)"
  type        = string
}

# 버전 관리 관련 변수
variable "enable_versioning" {
  description = "버전 관리 활성화 여부 (true/false)"
  type        = bool
}

# 보안 관련 변수
variable "uniform_bucket_level_access" {
  description = "균일한 버킷 수준 액세스 설정 여부 (true/false)"
  type        = bool
}

# CORS 관련 변수
variable "cors_origins" {
  description = "CORS 오리진 리스트 (예: [\"*\"] 또는 [\"https://example.com\"])"
  type        = list(string)
}

variable "cors_methods" {
  description = "CORS 허용 메소드 리스트 (예: [\"GET\", \"HEAD\", \"OPTIONS\"])"
  type        = list(string)
}

variable "cors_response_headers" {
  description = "CORS 응답 헤더 리스트 (예: [\"*\"])"
  type        = list(string)
}

variable "cors_max_age_seconds" {
  description = "CORS 캐시 시간(초) (예: 3600)"
  type        = number
}

# 라벨 관련 변수
variable "additional_labels" {
  description = "버킷에 적용할 추가 라벨 (예: { team = \"data\" })"
  type        = map(string)
}

variable "managed_by" {
  description = "리소스 관리 도구 (예: terraform)"
  type        = string
}

# ---------------------------------------
# Cloudflare 터널 정보 (보안 값, secrets.auto.tfvars에서 로드)
# ---------------------------------------
variable "cloudflare_tunnel_uuid" {
  description = "Cloudflare 터널 UUID (보안을 위해 secrets.auto.tfvars에 저장)"
  type        = string
  sensitive   = true # 보안 값으로 취급
}

# Discord 웹훅 URL (보안 값, secrets.auto.tfvars에서 로드)
variable "discord_webhook_url" {
  description = "Discord 알림용 웹훅 URL (보안을 위해 secrets.auto.tfvars에 저장)"
  type        = string
  sensitive   = true # 보안 값으로 취급
}

variable "github_actions_token" {
  description = "GitHub Actions 러너 등록 토큰"
  type        = string
  sensitive   = true
}

# Discord 웹훅 URL - AI 용
variable "discord_webhook_url_ai" {
  description = "Discord 알림용 웹훅 URL (보안을 위해 secrets.auto.tfvars에 저장)"
  type        = string
  sensitive   = true # 보안 값으로 취급
}
