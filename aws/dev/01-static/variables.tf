# 디스코드 웹훅 URL 변수
variable "discord_webhook_url" {
  description = "jacky의 디스코드 웹훅 URL"
  type        = string
  sensitive   = true
}

variable "discord_webhook_url_all" {
  description = "팀 전체용 디스코드 웹훅 URL"  
  type        = string
  sensitive   = true
}