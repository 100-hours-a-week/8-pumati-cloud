output "mig_name" {
  description = "관리형 인스턴스 그룹 이름"
  value       = google_compute_instance_group_manager.l4_spot_zonal.name
}

output "mig_region" {
  description = "관리형 인스턴스 그룹 리전"
  value       = local.region
}

output "mig_zone" {
  description = "관리형 인스턴스 그룹 존"
  value       = local.pd_zone
}

output "mig_id" {
  description = "관리형 인스턴스 그룹 ID"
  value       = google_compute_instance_group_manager.l4_spot_zonal.id
}

output "instance_templates" {
  description = "사용 가능한 인스턴스 템플릿들"
  value = {
    g2_standard_4 = google_compute_instance_template.g2_standard_4.id
    g2_standard_8 = google_compute_instance_template.g2_standard_8.id
  }
}

output "health_check_id" {
  description = "헬스 체크 ID"
  value       = google_compute_health_check.l4_spot.id
}

# 고정 IP 정보 추가
output "static_ip_address" {
  description = "T4 스팟 인스턴스용 고정 IP 주소"
  value       = google_compute_address.t4_static_ip.address
}

output "static_ip_name" {
  description = "T4 스팟 인스턴스용 고정 IP 이름"
  value       = google_compute_address.t4_static_ip.name
}