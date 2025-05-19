# Artifact Registry 저장소 생성
resource "google_artifact_registry_repository" "docker_registry" {
  provider      = google
  project       = var.project_id
  location      = var.location
  repository_id = var.repository_id
  description   = var.description
  format        = var.format
  labels        = var.labels
}
