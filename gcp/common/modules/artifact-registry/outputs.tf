output "repository_id" {
  description = "생성된 Artifact Registry의 ID"
  value       = google_artifact_registry_repository.docker_registry.repository_id
}

output "repository_name" {
  description = "생성된 Artifact Registry의 전체 이름"
  value       = google_artifact_registry_repository.docker_registry.name
}

output "repository_url" {
  description = "Docker 이미지를 푸시하기 위한 URL"
  value       = "${var.location}-docker.pkg.dev/${var.project_id}/${var.repository_id}"
}
