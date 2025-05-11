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

# Jenkins 영구 디스크 관련 출력
output "jenkins_master_disk_id" {
  description = "Jenkins 홈 디렉토리 디스크 ID"
  value       = module.jenkins_master_disk.id
}

output "jenkins_master_disk_name" {
  description = "Jenkins 홈 디렉토리 디스크 이름"
  value       = module.jenkins_master_disk.name
}

output "jenkins_master_disk_self_link" {
  description = "Jenkins 홈 디렉토리 디스크 self_link"
  value       = module.jenkins_master_disk.self_link
}

# Jenkins 에이전트 영구 디스크 관련 출력
output "jenkins_agent_disk_id" {
  description = "Jenkins 에이전트 디스크 ID"
  value       = module.jenkins_agent_disk.id
}

output "jenkins_agent_disk_name" {
  description = "Jenkins 에이전트 디스크 이름"
  value       = module.jenkins_agent_disk.name
}

output "jenkins_agent_disk_self_link" {
  description = "Jenkins 에이전트 디스크 self_link"
  value       = module.jenkins_agent_disk.self_link
}

# 디스코드 웹훅 시크릿 출력
output "discord_webhook_secret_id" {
  description = "디스코드 웹훅 URL 시크릿 ID"
  value       = module.discord_webhook_secret.secret_id
}