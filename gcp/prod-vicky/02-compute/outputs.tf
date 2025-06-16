output "mig_name" {
  description = "관리형 인스턴스 그룹 이름"
  value       = google_compute_instance_group_manager.l4_spot_zonal.name
}

output "mig_zone" {
  description = "관리형 인스턴스 그룹 존 (영구 디스크와 동일)"
  value       = google_compute_instance_group_manager.l4_spot_zonal.zone
}

output "mig_self_link" {
  description = "관리형 인스턴스 그룹 Self Link"
  value       = google_compute_instance_group_manager.l4_spot_zonal.self_link
}

output "instance_templates" {
  description = "생성된 인스턴스 템플릿들"
  value = {
    g2_standard_4  = google_compute_instance_template.g2_standard_4.name
    g2_standard_8  = google_compute_instance_template.g2_standard_8.name
  }
}

output "health_check" {
  description = "헬스 체크 정보"
  value = {
    name      = google_compute_health_check.l4_spot.name
    self_link = google_compute_health_check.l4_spot.self_link
  }
}

output "mig_info" {
  description = "MIG 전체 정보 (Zonal MIG with Persistent Disk Support)"
  value = {
    name        = google_compute_instance_group_manager.l4_spot_zonal.name
    zone        = google_compute_instance_group_manager.l4_spot_zonal.zone
    target_size = google_compute_instance_group_manager.l4_spot_zonal.target_size
    self_link   = google_compute_instance_group_manager.l4_spot_zonal.self_link
    machine_types = ["g2-standard-4", "g2-standard-8", "g2-standard-12"]
    persistent_disk_zone = local.pd_zone
    persistent_disk_name = local.pd_name
    zonal_mig = true
  }
}