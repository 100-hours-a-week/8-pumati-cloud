# modules/persistent-disk/outputs.tf - 영구 디스크 모듈 출력

output "disk_name" {
  description = "생성된 디스크 이름"
  value       = google_compute_disk.disk.name
}

output "disk_id" {
  description = "생성된 디스크 ID"
  value       = google_compute_disk.disk.id
}

output "self_link" {
  description = "생성된 디스크의 self_link"
  value       = google_compute_disk.disk.self_link
}

output "size" {
  description = "디스크 크기(GB)"
  value       = google_compute_disk.disk.size
}

output "disk_source" {
  description = "디스크 소스 (인스턴스 연결시 사용)"
  value       = google_compute_disk.disk.self_link
}

output "disk_users" {
  description = "디스크를 사용 중인 인스턴스 목록"
  value       = google_compute_disk.disk.users
}
