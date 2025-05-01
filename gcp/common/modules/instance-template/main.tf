# modules/mig/main.tf - MIG(Managed Instance Group) 모듈 정의

# 인스턴스 템플릿 생성
resource "google_compute_instance_template" "instance_template" {
  name_prefix  = "${var.instance_name}-template-"
  machine_type = var.machine_type
  region       = var.region
  
  # 스팟 인스턴스 설정
  scheduling {
    preemptible       = true
    automatic_restart = false
    provisioning_model = "SPOT"
  }
  
  disk {
    source_image = var.image
    auto_delete  = true
    boot         = true
    disk_size_gb = var.boot_disk_size
    disk_type    = var.boot_disk_type
  }
  
  # GPU 설정
  guest_accelerator {
    type  = var.gpu_type
    count = var.gpu_count
  }
  
  # GPU 사용을 위한 온디맨드 드라이버 설치 활성화
  metadata = {
    install-gpu-driver = "true"
  }
  
  network_interface {
    network = "default"
    access_config {
      // 외부 IP 할당
    }
  }
  
  # 시작 스크립트 설정
  metadata_startup_script = var.startup_script
  
  # 서비스 계정 설정
  service_account {
    email  = var.service_account_email
    scopes = var.service_account_scopes
  }
  
  # 태그 설정
  tags = ["gpu", "mig", "spot-instance"]
  
  # 수명 설정 (인스턴스 템플릿은 생성 후 24시간 후에 자동 삭제)
  lifecycle {
    create_before_destroy = true
  }
}

# 영역 인스턴스 그룹 관리자 생성
resource "google_compute_instance_group_manager" "mig" {
  name               = "${var.instance_name}-mig"
  base_instance_name = var.base_instance_name
  zone               = var.zone
  
  version {
    instance_template = google_compute_instance_template.instance_template.id
  }
  
  # 자동 복구 설정
  auto_healing_policies {
    health_check      = google_compute_health_check.autohealing.id
    initial_delay_sec = 300
  }
  
  # 대상 크기 설정
  target_size = var.target_size
  
  # 대기 시간(업데이트 중 인스턴스 대체 시 대기 시간)
  wait_for_instances = true
  
  # 업데이트 정책
  update_policy {
    type                           = "PROACTIVE"
    minimal_action                 = "REPLACE"
    most_disruptive_allowed_action = "REPLACE"
    max_surge_fixed                = 1
    max_unavailable_fixed          = 0
  }
}

# 상태 점검 설정
resource "google_compute_health_check" "autohealing" {
  name                = "${var.instance_name}-autohealing-health-check"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 10
  
  http_health_check {
    request_path = "/health"
    port         = "80"
  }
} 