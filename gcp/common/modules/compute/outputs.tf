# modules/compute/outputs.tf - 컴퓨팅 모듈 출력 정의

output "instance_id" {
  description = "생성된 인스턴스의 ID"
  value       = google_compute_instance.gpu_instance.id
}

output "instance_name" {
  description = "생성된 인스턴스의 이름"
  value       = google_compute_instance.gpu_instance.name
}

output "instance_self_link" {
  description = "생성된 인스턴스의 자체 링크"
  value       = google_compute_instance.gpu_instance.self_link
}

output "instance_external_ip" {
  description = "생성된 인스턴스의 외부 IP 주소"
  value       = google_compute_instance.gpu_instance.network_interface[0].access_config[0].nat_ip
}

output "instance_internal_ip" {
  description = "생성된 인스턴스의 내부 IP 주소"
  value       = google_compute_instance.gpu_instance.network_interface[0].network_ip
} 