# 고정 IP 주소 생성 (main.tf에 추가)
# resource "google_compute_address" "l4_static_ip" {
#   name         = "l4-spot-static-ip"
#   project      = local.project_id
#   region       = "asia-east1"
#   address_type = "EXTERNAL"  # 외부 IP 사용
#   description  = "L4 스팟 인스턴스용 고정 IP"
#   
#   # 라벨 추가
#   labels = local.common_labels
# }

# 추가 포트용 방화벽 규칙
# resource "google_compute_firewall" "l4_spot_additional_ports" {
#   name    = "l4-spot-additional-ports"
#   network = "default"
#   project = local.project_id
#   
#   allow {
#     protocol = "tcp"
#     ports    = ["8000", "8080"]
#   }
#   
#   # MIG 인스턴스에만 적용 (네트워크 태그 사용)
#   target_tags = ["l4-spot"]
#   
#   # 모든 IP에서 접근 허용 (필요에 따라 제한 가능)
#   source_ranges = ["0.0.0.0/0"]
# }

# 여러 머신 타입을 자동으로 시도하는 Instance Templates 생성
# GCP MIG가 자동으로 가용한 머신 타입을 선택합니다

# 기본 머신 타입용 인스턴스 템플릿 (g2-standard-4)
resource "google_compute_instance_template" "g2_standard_4" {
  name_prefix  = "l4-spot-g2std4-"
  project      = local.project_id
  machine_type = "g2-standard-8"

  # 스팟 인스턴스 설정
  scheduling {
    preemptible        = true
    automatic_restart  = false
    provisioning_model = "SPOT"
  }

  # 부팅 디스크 설정
  disk {
    source_image = "projects/deeplearning-platform-release/global/images/family/pytorch-latest-gpu"
    auto_delete  = true
    boot         = true
    disk_size_gb = 100
    disk_type    = "pd-balanced"
  }

  # GPU 설정
  guest_accelerator {
    type  = "nvidia-l4"
    count = 1
  }

  # 메타데이터
  metadata = {
    "install-gpu-driver" = "true"
    "enable-osconfig"    = "true"
    "machine-type"       = "g2-standard-4"
  }

  metadata_startup_script = local.final_startup_script

  # 네트워크 설정
  network_interface {
    network = "default"
    access_config {}
  }

  # 서비스 계정
  service_account {
    email  = "terraform@ambient-topic-459110-e6.iam.gserviceaccount.com"
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  tags   = ["l4-spot", "g2-standard-4"]
  labels = merge(local.common_labels, { machine-type = "g2_standard_4" })

  lifecycle {
    create_before_destroy = true
  }
}

# 대체 머신 타입용 인스턴스 템플릿 (g2-standard-8)
resource "google_compute_instance_template" "g2_standard_8" {
  name_prefix  = "l4-spot-g2std8-"
  project      = local.project_id
  machine_type = "g2-standard-12"

  # 스팟 인스턴스 설정
  scheduling {
    preemptible        = true
    automatic_restart  = false
    provisioning_model = "SPOT"
  }

  # 부팅 디스크 설정
  disk {
    source_image = "projects/deeplearning-platform-release/global/images/family/pytorch-latest-gpu"
    auto_delete  = true
    boot         = true
    disk_size_gb = 100
    disk_type    = "pd-balanced"
  }

  # GPU 설정
  guest_accelerator {
    type  = "nvidia-l4"
    count = 1
  }

  # 메타데이터
  metadata = {
    "install-gpu-driver" = "true"
    "enable-osconfig"    = "true"
    "machine-type"       = "g2-standard-8"
  }

  metadata_startup_script = local.final_startup_script

  # 네트워크 설정
  network_interface {
    network = "default"
    access_config {}
  }

  # 서비스 계정
  service_account {
    email  = "terraform@ambient-topic-459110-e6.iam.gserviceaccount.com"
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  tags   = ["l4-spot", "g2-standard-8"]
  labels = merge(local.common_labels, { machine-type = "g2_standard_8" })

  lifecycle {
    create_before_destroy = true
  }
}

# 헬스 체크
resource "google_compute_health_check" "l4_spot" {
  name                = "l4-spot-hc"
  project             = local.project_id
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  tcp_health_check {
    port = 22
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Zonal MIG - 올바른 다중 버전 설정
resource "google_compute_instance_group_manager" "l4_spot_zonal" {
  name               = "l4-spot-zonal-mig"
  project            = local.project_id
  zone               = local.pd_zone
  base_instance_name = "l4-spot"

  depends_on = [
    google_compute_instance_template.g2_standard_4,
    google_compute_instance_template.g2_standard_8,
    google_compute_health_check.l4_spot
  ]

  # 올바른 버전 설정
  version {
    instance_template = google_compute_instance_template.g2_standard_4.id
    # target_size 없음 = 기본 버전 (우선 시도)
  }

  version {
    instance_template = google_compute_instance_template.g2_standard_8.id
    target_size {
      percent = 0  # 0%로 설정 = 대체 버전으로만 사용
    }
  }

  target_size        = 1
  wait_for_instances = true

  # 업데이트 정책 - 자동 전환 최적화
  update_policy {
    type                           = "PROACTIVE"
    minimal_action                 = "REPLACE"
    most_disruptive_allowed_action = "REPLACE"
    max_surge_fixed                = 0
    max_unavailable_fixed          = 1
    replacement_method             = "RECREATE"
  }

  # 포트 설정
  named_port {
    name = "http"
    port = 80
  }

  named_port {
    name = "https"
    port = 443
  }

  named_port {
    name = "port-8000"
    port = 8000
  }

  named_port {
    name = "port-8080"
    port = 8080
  }

  # 자동 복구
  auto_healing_policies {
    health_check      = google_compute_health_check.l4_spot.id
    initial_delay_sec = 300
  }

  lifecycle {
    ignore_changes = [
      version[0].instance_template,
      version[1].instance_template,
      target_size,
    ]
    create_before_destroy = false
  }
}
