# modules/mig/outputs.tf - MIG 모듈 출력 값 정의

output "instance_group" {
  description = "생성된 인스턴스 그룹 ID"
  value       = google_compute_region_instance_group_manager.mig.instance_group
}

output "instance_group_manager_id" {
  description = "생성된 인스턴스 그룹 매니저 ID"
  value       = google_compute_region_instance_group_manager.mig.id
}

output "instance_group_manager_self_link" {
  description = "생성된 인스턴스 그룹 매니저 self_link"
  value       = google_compute_region_instance_group_manager.mig.self_link
}

output "available_templates" {
  description = "사용 가능한, 정의된 템플릿 정보"
  value = {
    l4 = {
      id        = google_compute_instance_template.l4_instance_template.id
      self_link = google_compute_instance_template.l4_instance_template.self_link
    }
    t4 = {
      id        = google_compute_instance_template.t4_instance_template.id
      self_link = google_compute_instance_template.t4_instance_template.self_link
    }
    p100 = {
      id        = google_compute_instance_template.p100_instance_template.id
      self_link = google_compute_instance_template.p100_instance_template.self_link
    }
  }
}

output "health_check_self_link" {
  description = "인스턴스 자동 복구를 위한 상태 확인 self_link"
  value       = google_compute_health_check.autohealing.self_link
}
