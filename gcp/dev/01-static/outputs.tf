# outputs.tf - 출력 변수 정의 파일

# output "bucket_name" {
#   description = "생성된 버킷의 이름"
#   value       = module.gcs.bucket_name
# }

# output "bucket_url" {
#   description = "생성된 버킷의 URL"
#   value       = module.gcs.bucket_url
# }

# output "bucket_self_link" {
#   description = "생성된 버킷의 자체 링크"
#   value       = module.gcs.bucket_self_link
# }

# 아티팩트 레지스트리 관련 출력 추가
output "docker_registry_id" {
  description = "생성된 Docker 레지스트리의 ID"
  value       = module.docker_registry.repository_id
}

output "docker_registry_name" {
  description = "생성된 Docker 레지스트리의 전체 이름"
  value       = module.docker_registry.repository_name
}

output "docker_registry_url" {
  description = "Docker 이미지를 푸시하기 위한 URL"
  value       = module.docker_registry.repository_url
}

# 시크릿 관련 출력 추가
output "cloudflare_tunnel_secret_id" {
  description = "Cloudflare 터널 UUID 시크릿의 ID"
  value       = module.cloudflare_tunnel_secret.secret_id
}

output "discord_webhook_secret_id" {
  description = "Discord 웹훅 URL 시크릿의 ID"
  value       = module.discord_webhook_secret.secret_id
}

output "github_token_secret_id" {
  description = "GitHub Actions 토큰 시크릿의 ID"
  value       = module.github_token_secret.secret_id
}

output "sa_key_secret_id" {
  description = "Service Account 키 시크릿의 ID"
  value       = module.sa_key_secret.secret_id
}

output "discord_webhook_secret_ai_id" {
  description = "Discord 웹훅 URL 시크릿의 ID"
  value       = module.discord_webhook_secret_ai.secret_id
}

# 영구 디스크 출력 추가
output "persistent_disk_name" {
  description = "생성된 영구 디스크 이름"
  value       = module.persistent_disk.disk_name
}

output "persistent_disk_zone" {
  description = "스팟 인스턴스용 영구 디스크 존"
  value       = local.zone
}

output "persistent_disk_id" {
  description = "생성된 영구 디스크 ID"
  value       = module.persistent_disk.disk_id
}
