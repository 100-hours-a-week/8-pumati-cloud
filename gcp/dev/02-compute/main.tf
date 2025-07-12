# 고정 IP 주소 생성 - 주석 해제하고 T4용으로 수정
resource "google_compute_address" "t4_static_ip" {
  name         = "t4-spot-static-ip"
  project      = local.project_id
  region       = local.region
  address_type = "EXTERNAL"  # 외부 IP 사용
  description  = "T4 스팟 인스턴스용 고정 IP"
  
  # 라벨 추가
  labels = local.common_labels
}

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

# SSH 접속용 방화벽 규칙 추가
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh-dev"
  network = "default"
  project = local.project_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags   = ["t4-spot"]  # 인스턴스 태그와 일치
  source_ranges = ["0.0.0.0/0"]
}

# 여러 머신 타입을 자동으로 시도하는 Instance Templates 생성
# GCP MIG가 자동으로 가용한 머신 타입을 선택합니다

# 기본 머신 타입용 인스턴스 템플릿 (n1-standard-4)
resource "google_compute_instance_template" "g2_standard_4" {
  name_prefix  = "t4-spot-n1std4-"
  project      = local.project_id
  machine_type = "n1-standard-4"

  # GPU 설정 - T4로 변경
  guest_accelerator {
    type  = "nvidia-tesla-t4"
    count = 1
  }

  # 스팟 인스턴스 설정 - 방법 1: preemptible 방식 (권장)
  scheduling {
    preemptible                = true    # 스팟 인스턴스 활성화
    automatic_restart          = false   # 스팟 인스턴스는 자동 재시작 불가
    on_host_maintenance        = "TERMINATE"  # GPU 인스턴스는 라이브 마이그레이션 불가
  }

  # 부팅 디스크 설정
  disk {
    source_image = "projects/deeplearning-platform-release/global/images/family/pytorch-latest-gpu"
    auto_delete  = true
    boot         = true
    disk_size_gb = 100
    disk_type    = "pd-standard"  # SSD 쿼터 회피
  }

  # 메타데이터
  metadata = {
    "install-gpu-driver" = "true"
    "enable-osconfig"    = "true"
    "machine-type"       = "n1-standard-4"
    "ssh-keys"          = "hyunsik:${file("/Users/hyunsik/.ssh/key-dev-anna.pub")}"
  }

  metadata_startup_script = local.final_startup_script

  # 네트워크 설정
  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.t4_static_ip.address  # 고정 IP 할당
    }
  }

  # 서비스 계정
  service_account {
    email  = "terraform@dev-anna-465601.iam.gserviceaccount.com"
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  tags   = ["t4-spot", "n1-standard-4"]
  labels = merge(local.common_labels, { machine-type = "n1_standard_4" })

  lifecycle {
    create_before_destroy = true
  }
}

# 대체 머신 타입용 인스턴스 템플릿 (n1-standard-8)
resource "google_compute_instance_template" "g2_standard_8" {
  name_prefix  = "t4-spot-n1std8-"
  project      = local.project_id
  machine_type = "n1-standard-8"

  # GPU 설정 - T4로 변경
  guest_accelerator {
    type  = "nvidia-tesla-t4"
    count = 1
  }

  # 스팟 인스턴스 설정 - 방법 1: preemptible 방식 (권장)
  scheduling {
    preemptible                = true    # 스팟 인스턴스 활성화
    automatic_restart          = false   # 스팟 인스턴스는 자동 재시작 불가
    on_host_maintenance        = "TERMINATE"  # GPU 인스턴스는 라이브 마이그레이션 불가
  }

  # 부팅 디스크 설정
  disk {
    source_image = "projects/deeplearning-platform-release/global/images/family/pytorch-latest-gpu"
    auto_delete  = true
    boot         = true
    disk_size_gb = 100
    disk_type    = "pd-standard"  # SSD 쿼터 회피
  }

  # 메타데이터
  metadata = {
    "install-gpu-driver" = "true"
    "enable-osconfig"    = "true"
    "machine-type"       = "n1-standard-8"
    "ssh-keys"          = "hyunsik:${file("/Users/hyunsik/.ssh/key-dev-anna.pub")}"
  }

  metadata_startup_script = local.final_startup_script

  # 네트워크 설정 - 고정 IP 사용
  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.t4_static_ip.address  # 고정 IP 할당
    }
  }

  # 서비스 계정
  service_account {
    email  = "terraform@dev-anna-465601.iam.gserviceaccount.com"
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  tags   = ["t4-spot", "n1-standard-8"]
  labels = merge(local.common_labels, { machine-type = "n1_standard_8" })

  lifecycle {
    create_before_destroy = true
  }
}

# 헬스 체크 - 이름 변경
resource "google_compute_health_check" "l4_spot" {
  name                = "t4-spot-hc"
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

# Zonal MIG - T4 스팟 인스턴스용
resource "google_compute_instance_group_manager" "l4_spot_zonal" {
  name               = "t4-spot-zonal-mig"
  project            = local.project_id
  zone               = local.pd_zone  # dev 환경의 zone 설정
  base_instance_name = "t4-spot"

  depends_on = [
    google_compute_instance_template.g2_standard_4,
    google_compute_instance_template.g2_standard_8,
    google_compute_health_check.l4_spot
  ]

  # 여러 버전 설정 - 스팟 인스턴스 가용성 최적화
  version {
    instance_template = google_compute_instance_template.g2_standard_4.id
    # target_size 없음 = 기본 버전 (우선 시도)
  }

  version {
    instance_template = google_compute_instance_template.g2_standard_8.id
    target_size {
      fixed = 0 # 대체 버전으로만 사용
    }
  }

  target_size        = 1
  wait_for_instances = true

  # 업데이트 정책 - 스팟 인스턴스 최적화
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

  # 자동 복구 - 스팟 인스턴스에 적합하게 설정
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
