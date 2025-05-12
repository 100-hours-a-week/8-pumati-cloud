# modules/mig/outputs.tf
# MIG 모듈 출력 값 - 다른 모듈이나 외부 스크립트에서 참조할 수 있는 값들

# 인스턴스 그룹 ID
# 로드 밸런서 연결 등에 사용
output "instance_group" {
  description = "생성된 인스턴스 그룹 ID (로드 밸런서 백엔드 등에 사용)"
  value       = google_compute_instance_group_manager.this.instance_group
}

# 인스턴스 그룹 매니저 ID
# MIG 식별을 위한 고유 ID
output "instance_group_manager_id" {
  description = "생성된 인스턴스 그룹 매니저 ID (리소스 참조용)"
  value       = google_compute_instance_group_manager.this.id
}

# 인스턴스 그룹 매니저 self_link
# API 호출 등에 사용
output "instance_group_manager_self_link" {
  description = "생성된 인스턴스 그룹 매니저 self_link (API 호출에 사용)"
  value       = google_compute_instance_group_manager.this.self_link
}

# 인스턴스 템플릿 ID
# 다른 템플릿과 구분하기 위한 식별자
output "instance_template_id" {
  description = "생성된 인스턴스 템플릿 ID"
  value       = google_compute_instance_template.this.id
}

# 인스턴스 템플릿 self_link
# 외부 스크립트에서 템플릿을 참조할 때 사용
output "instance_template_self_link" {
  description = "생성된 인스턴스 템플릿 self_link (외부 스크립트에서 참조용)"
  value       = google_compute_instance_template.this.self_link
}

# 헬스 체크 self_link
# 로드 밸런서나 다른 서비스에서 참조할 때 사용
output "health_check_self_link" {
  description = "인스턴스 자동 복구를 위한 상태 확인 self_link"
  value       = google_compute_health_check.this.self_link
}

# 배포 영역 목록
# 인스턴스가 어떤 존에 배포될 수 있는지 확인
output "distribution_zones" {
  description = "MIG가 인스턴스를 배포할 수 있는 영역 목록"
  value       = var.zone
}

# MIG 이름
# 외부 스크립트에서 gcloud 등으로 조회할 때 사용
output "mig_name" {
  description = "MIG 이름 (자동화 스크립트에서 사용)"
  value       = google_compute_instance_group_manager.this.name
}

# GPU 유형 정보
# 어떤 GPU가 사용되었는지 확인
output "gpu_info" {
  description = "사용된 GPU 유형 및 개수 정보"
  value = {
    type  = var.gpu_type
    count = var.gpu_count
  }
}

# 리전 정보
output "region" {
  description = "MIG가 배포된 리전"
  value       = var.region
}
