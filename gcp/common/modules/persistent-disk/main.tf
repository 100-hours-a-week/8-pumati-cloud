# modules/persistent-disk/main.tf - 영구 디스크 모듈

resource "google_compute_disk" "disk" {
  name        = var.disk_name
  description = var.description
  type        = var.disk_type
  size        = var.disk_size
  zone        = var.zone
  project     = var.project_id
  labels      = var.labels
}
