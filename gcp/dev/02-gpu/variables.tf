# variables.tf - CloudFlare 및 Discord 관련 변수

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

