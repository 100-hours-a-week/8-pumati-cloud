# variables.tf - CloudFlare 및 Discord 관련 변수

variable "use_custom_image" {
  description = "커스텀 이미지를 사용할지 여부"
  type        = bool
}

# Cloudflare 터널 정보 (보안 값, secrets.auto.tfvars에서 로드)
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

variable "custom_image_name" {
  description = "사용할 커스텀 이미지 이름 (use_custom_image=true인 경우 필수)"
  type        = string
}

# 기본 이미지 관련 변수 추가
variable "default_image_family" {
  description = "기본 이미지 패밀리 (use_custom_image=false인 경우 사용)"
  type        = string
}

variable "default_image_project" {
  description = "기본 이미지 프로젝트 (use_custom_image=false인 경우 사용)"
  type        = string
}