# modules/mig/outputs.tf - MIG 모듈 출력 정의

output "instance_group" {
  description = "인스턴스 그룹"
  value       = google_compute_instance_group_manager.mig.instance_group
}

output "mig_self_link" {
  description = "MIG 자체 링크"
  value       = google_compute_instance_group_manager.mig.self_link
}

output "mig_name" {
  description = "MIG 이름"
  value       = google_compute_instance_group_manager.mig.name
}

output "instance_template" {
  description = "인스턴스 템플릿"
  value       = google_compute_instance_template.instance_template.self_link
}

output "health_check_self_link" {
  description = "상태 확인 자체 링크"
  value       = google_compute_health_check.autohealing.self_link
} 