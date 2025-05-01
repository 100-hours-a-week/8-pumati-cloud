# modules/mig/main.tf - MIG(Managed Instance Group) 모듈 정의

#########################################################
# GPU 우선순위 기반 인스턴스 템플릿 정의
# 각 템플릿은 GPU 타입만 다르고 나머지 설정은 동일
#########################################################

# 인스턴스 템플릿 생성 - L4 GPU 구성 (최우선 사용)
resource "google_compute_instance_template" "l4_instance_template" {
  name_prefix  = "${var.instance_name}-l4-"
  machine_type = var.machine_type
  project      = var.project_id
  
  # 스팟 인스턴스 설정
  scheduling {
    preemptible        = var.spot
    automatic_restart  = false
    provisioning_model = var.spot ? "SPOT" : "STANDARD"
  }
  
  # 부팅 디스크 설정 - L4 GPU 워크로드에 최적화된 설정
  disk {
    source_image = "debian-cloud/debian-11" # L4 GPU 지원 이미지
    auto_delete  = true
    boot         = true
    disk_size_gb = 100 # 기본 100GB 할당
    disk_type    = "pd-ssd" # SSD 스토리지로 성능 최적화
  }
  
  # L4 GPU 구성 - 최신 NVIDIA L4 GPU
  guest_accelerator {
    type  = "nvidia-l4"
    count = 1 # 1개의 L4 GPU 할당
  }
  
  # GPU 드라이버 자동 설치 활성화
  metadata = merge(
    { "install-gpu-driver" = "true" },
    var.additional_metadata
  )
  
  # 네트워크 설정
  network_interface {
    network = var.network
    access_config {
      // 임시 외부 IP 할당
    }
  }
  
  # 서비스 계정 설정
  service_account {
    email  = var.service_account_email
    scopes = var.service_account_scopes
  }
  
  # 시작 스크립트
  metadata_startup_script = var.startup_script
  
  # 네트워크 태그와 라벨
  tags   = var.tags
  labels = var.labels
  
  # 인스턴스 템플릿 생성 시 고유 ID 생성을 위한 설정
  lifecycle {
    create_before_destroy = true
  }
}

# 인스턴스 템플릿 생성 - T4 GPU 구성 (L4 할당량이 없을 경우 대체용)
resource "google_compute_instance_template" "t4_instance_template" {
  name_prefix  = "${var.instance_name}-t4-"
  machine_type = var.machine_type
  project      = var.project_id
  
  # 스팟 인스턴스 설정
  scheduling {
    preemptible        = var.spot
    automatic_restart  = false
    provisioning_model = var.spot ? "SPOT" : "STANDARD"
  }
  
  # 부팅 디스크 설정 - T4 GPU 워크로드에 최적화된 설정
  disk {
    source_image = "debian-cloud/debian-11" # T4 GPU 지원 이미지
    auto_delete  = true
    boot         = true
    disk_size_gb = 100 # 기본 100GB 할당
    disk_type    = "pd-ssd" # SSD 스토리지로 성능 최적화
  }
  
  # T4 GPU 구성 - L4 대비 성능은 다소 낮지만 더 보편적으로 사용 가능
  guest_accelerator {
    type  = "nvidia-tesla-t4"
    count = 1 # 1개의 T4 GPU 할당
  }
  
  # GPU 드라이버 자동 설치 활성화
  metadata = merge(
    { "install-gpu-driver" = "true" },
    var.additional_metadata
  )
  
  # 네트워크 설정
  network_interface {
    network = var.network
    access_config {
      // 임시 외부 IP 할당
    }
  }
  
  # 서비스 계정 설정
  service_account {
    email  = var.service_account_email
    scopes = var.service_account_scopes
  }
  
  # 시작 스크립트
  metadata_startup_script = var.startup_script
  
  # 네트워크 태그와 라벨
  tags   = var.tags
  labels = var.labels
  
  # 인스턴스 템플릿 생성 시 고유 ID 생성을 위한 설정
  lifecycle {
    create_before_destroy = true
  }
}

# 인스턴스 템플릿 생성 - P100 GPU 구성 (L4/T4 모두 할당량이 없을 경우 대체용)
resource "google_compute_instance_template" "p100_instance_template" {
  name_prefix  = "${var.instance_name}-p100-"
  machine_type = var.machine_type
  project      = var.project_id
  
  # 스팟 인스턴스 설정
  scheduling {
    preemptible        = var.spot
    automatic_restart  = false
    provisioning_model = var.spot ? "SPOT" : "STANDARD"
  }
  
  # 부팅 디스크 설정 - P100 GPU 워크로드에 최적화된 설정
  disk {
    source_image = "debian-cloud/debian-11" # P100 GPU 지원 이미지
    auto_delete  = true
    boot         = true
    disk_size_gb = 100 # 기본 100GB 할당
    disk_type    = "pd-ssd" # SSD 스토리지로 성능 최적화
  }
  
  # P100 GPU 구성 - 구형 GPU이지만 대체용으로 사용
  guest_accelerator {
    type  = "nvidia-tesla-p100"
    count = 1 # 1개의 P100 GPU 할당
  }
  
  # GPU 드라이버 자동 설치 활성화
  metadata = merge(
    { "install-gpu-driver" = "true" },
    var.additional_metadata
  )
  
  # 네트워크 설정
  network_interface {
    network = var.network
    access_config {
      // 임시 외부 IP 할당
    }
  }
  
  # 서비스 계정 설정
  service_account {
    email  = var.service_account_email
    scopes = var.service_account_scopes
  }
  
  # 시작 스크립트
  metadata_startup_script = var.startup_script
  
  # 네트워크 태그와 라벨
  tags   = var.tags
  labels = var.labels
  
  # 인스턴스 템플릿 생성 시 고유 ID 생성을 위한 설정
  lifecycle {
    create_before_destroy = true
  }
}

#########################################################
# 우선순위 기반 관리형 인스턴스 그룹 (MIG) 생성
# GPU 할당량 문제 발생 시 자동으로 대체 GPU 사용
#########################################################

resource "google_compute_region_instance_group_manager" "mig" {
  name               = "${var.instance_name}-mig"
  base_instance_name = var.instance_name
  region             = var.region
  project            = var.project_id
  
  # 상태 확인 및 자동 복구 설정
  # 인스턴스에 문제가 있을 때 자동으로 재생성
  auto_healing_policies {
    health_check      = google_compute_health_check.autohealing.id
    initial_delay_sec = var.initial_delay_sec
  }
  
  #########################################################
  # 버전 기반 우선순위 전략
  # 이 부분이 GPU 할당량에 따른 자동 대체 구현의 핵심
  #########################################################
  
  # 첫 번째 버전: L4 GPU (최우선 사용)
  version {
    name              = "l4"
    instance_template = google_compute_instance_template.l4_instance_template.id
    # 이 버전으로 1개 인스턴스 생성 시도
    target_size {
      fixed = 1
    }
  }
  
  # 두 번째 버전: T4 GPU (L4 할당량 초과 시 사용)
  version {
    name              = "t4"
    instance_template = google_compute_instance_template.t4_instance_template.id
    # 기본적으로는 이 버전으로 인스턴스 생성 안 함
    # L4 생성 실패 시 이 버전으로 대체
    target_size {
      fixed = 0
    }
  }
  
  # 세 번째 버전: P100 GPU (L4/T4 모두 할당량 초과 시 사용)
  version {
    name              = "p100"
    instance_template = google_compute_instance_template.p100_instance_template.id
    # 기본적으로는 이 버전으로 인스턴스 생성 안 함
    # L4/T4 생성 실패 시 이 버전으로 대체
    target_size {
      fixed = 0
    }
  }
  
  # 총 인스턴스 수는 1개로 제한
  target_size = 1
  
  # 버전 관리 정책 - GPU 할당량 초과 시 대체 템플릿 사용
  update_policy {
    # PROACTIVE: 템플릿 변경 시 인스턴스를 적극적으로 업데이트
    type                           = var.update_type
    # NONE: 인스턴스 재분배 안 함 (영역 간 이동 방지)
    instance_redistribution_type   = var.instance_redistribution_type
    # REPLACE: 인스턴스를 교체하는 방식으로 업데이트
    minimal_action                 = var.minimal_action
    most_disruptive_allowed_action = var.most_disruptive_allowed_action
    # max_surge_fixed=0: 새 인스턴스 생성 전 기존 인스턴스 제거
    max_surge_fixed                = var.max_surge_fixed
    # max_unavailable_fixed=1: 최대 1개 인스턴스가 사용 불가능한 상태 허용
    max_unavailable_fixed          = var.max_unavailable_fixed
    # SUBSTITUTE: GPU 할당량 문제 시 다른 템플릿으로 대체 가능
    replacement_method             = var.replacement_method
  }
  
  # HTTP/HTTPS 포트 설정
  named_port {
    name = "http"
    port = var.http_port
  }
  
  named_port {
    name = "https"
    port = var.https_port
  }
  
  # 자동 확장 정책 비활성화 (고정 크기 사용)
  # 이 설정이 없으면 Terraform이 버전별 target_size를 관리하려 함
  lifecycle {
    ignore_changes = [
      version[0].target_size,
      version[1].target_size,
      version[2].target_size,
    ]
  }
  
  # 인스턴스 생성 완료 대기
  # 이 설정이 없으면 인스턴스 생성 완료 전에 Terraform 실행 완료
  wait_for_instances = var.wait_for_instances
}

# 인스턴스 자동 복구를 위한 상태 확인
resource "google_compute_health_check" "autohealing" {
  name                = "${var.instance_name}-autohealing-health-check"
  check_interval_sec  = var.check_interval_sec
  timeout_sec         = var.timeout_sec
  healthy_threshold   = var.healthy_threshold
  unhealthy_threshold = var.unhealthy_threshold
  project             = var.project_id
  
  # SSH 포트 확인으로 VM 상태 모니터링
  tcp_health_check {
    port = var.health_check_port
  }
}
