# modules/compute/main.tf - 컴퓨팅 인스턴스 모듈

# 로컬 변수 정의
locals {
  # 외부 디스크 연결 여부
  attach_external_disk = var.external_disk != null
}

# 고정 IP 주소 생성
resource "google_compute_address" "static_ip" {
  name    = var.static_ip_name
  project = var.project_id
  region  = var.region
}

# 인스턴스 생성
resource "google_compute_instance" "instance" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone
  project      = var.project_id
  
  # 스팟/선점형 인스턴스 설정
  scheduling {
    preemptible        = var.spot
    automatic_restart  = !var.spot
    provisioning_model = var.spot ? "SPOT" : "STANDARD"
  }
  
  # 부팅 디스크 설정
  boot_disk {
    initialize_params {
      image = var.boot_disk_image
      size  = var.boot_disk_size
      type  = var.boot_disk_type
    }
  }
  
  # 외부 디스크 연결 (외부 디스크 설정이 있는 경우)
  dynamic "attached_disk" {
    for_each = local.attach_external_disk ? [1] : []
    content {
      source      = var.external_disk.source
      device_name = var.external_disk.device_name
    }
  }
  
  # GPU 구성 (필요한 경우)
  dynamic "guest_accelerator" {
    for_each = var.gpu_count > 0 ? [1] : []
    content {
      type  = var.gpu_type
      count = var.gpu_count
    }
  }
  
  # 네트워크 설정
  network_interface {
    network = var.network
    access_config {
      nat_ip = google_compute_address.static_ip.address
    }
  }
  
  # 메타데이터 설정
  metadata = merge(
    var.gpu_count > 0 ? { install-gpu-driver = "true" } : {},
    var.additional_metadata
  )
  
  # 시작 스크립트
  metadata_startup_script = var.startup_script
  
  # 서비스 계정 설정
  service_account {
    email  = var.service_account_email
    scopes = var.service_account_scopes
  }
  
  # 태그 및 라벨
  tags   = var.tags
  labels = var.labels
}

# 방화벽 규칙 설정
resource "google_compute_firewall" "firewall" {
  name    = var.firewall_rules.name
  network = var.network
  project = var.project_id
  
  allow {
    protocol = var.firewall_rules.protocol
    ports    = var.firewall_rules.ports
  }
  
  source_ranges = var.firewall_rules.source_ranges
  target_tags   = var.tags
}