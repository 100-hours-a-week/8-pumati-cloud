output "mig_name" {
  description = "관리형 인스턴스 그룹 이름"
  value       = google_compute_region_instance_group_manager.l4_spot_flexible.name
}

output "mig_region" {
  description = "관리형 인스턴스 그룹 리전"
  value       = google_compute_region_instance_group_manager.l4_spot_flexible.region
}

output "mig_self_link" {
  description = "관리형 인스턴스 그룹 Self Link"
  value       = google_compute_region_instance_group_manager.l4_spot_flexible.self_link
}

output "instance_templates" {
  description = "생성된 인스턴스 템플릿들"
  value = {
    g2_standard_4  = google_compute_instance_template.g2_standard_4.name
    g2_standard_8  = google_compute_instance_template.g2_standard_8.name
    g2_standard_12 = google_compute_instance_template.g2_standard_12.name
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
  description = "MIG 전체 정보"
  value = {
    name        = google_compute_region_instance_group_manager.l4_spot_flexible.name
    region      = google_compute_region_instance_group_manager.l4_spot_flexible.region
    target_size = google_compute_region_instance_group_manager.l4_spot_flexible.target_size
    self_link   = google_compute_region_instance_group_manager.l4_spot_flexible.self_link
    machine_types = ["g2-standard-4", "g2-standard-8", "g2-standard-12"]
    zones_available = ["asia-east1-a", "asia-east1-b", "asia-east1-c"]
    flexibility_enabled = true
  }
}