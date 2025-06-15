# modules/mig/main.tf
# L4/T4/P100 GPU를 사용하는 스팟 인스턴스를 MIG로 관리
# 목표: 
# 1. 스팟 인스턴스가 종료되면 자동으로 재생성
# 2. 여러 존에 걸쳐 GPU 가용성 문제를 해결 (자동 존 페일오버)
# 3. 한 리전 내에서 최대 한 대의 GPU 인스턴스 실행 보장

# 인스턴스 템플릿 정의
# 동일한 설정의 VM이 반복적으로 생성될 수 있도록 템플릿화
resource "google_compute_instance_template" "this" {
  # 이름 접두사 (실제 생성 시 타임스탬프가 추가됨)
  name_prefix  = "${var.instance_name}-"
  project      = var.project_id
  machine_type = var.machine_type

  # 스팟(선점형) 인스턴스 설정
  # 비용 절감을 위해 스팟 사용, 시장 상황에 따라 회수될 수 있음
  scheduling {
    preemptible        = var.spot
    automatic_restart  = false
    provisioning_model = var.spot ? "SPOT" : "STANDARD"
  }

  # 부팅 디스크 설정 - 소스 이미지 분기 처리 (Null 방지)
  disk {
    # 이미지 참조 방식에 따라 분기
    source_image = var.source_image != "" ? var.source_image : (
      "${var.source_image_project != "" ? "projects/${var.source_image_project}/" : ""}global/images/family/${var.source_image_family}"
    )
    auto_delete  = true             # 인스턴스 삭제 시 디스크도 자동 삭제
    boot         = true
    disk_size_gb = var.disk_size_gb # GPU 워크로드는 100GB 이상 권장
    disk_type    = var.disk_type    # pd-ssd가 성능 향상에 도움
  }

  # GPU 설정
  # 인스턴스에 할당할 GPU 유형과 개수
  guest_accelerator {
    type  = var.gpu_type  # "nvidia-l4", "nvidia-tesla-t4", "nvidia-tesla-p100" 등
    count = var.gpu_count # 일반적으로 1
  }

  # 메타데이터와 시작 스크립트에 운영 에이전트 설치 코드 추가
  metadata = merge(
    {
      "install-gpu-driver" = "true", # GPU 드라이버 자동 설치 활성화
      "enable-osconfig"    = "true"  # OS 구성 관리 활성화 (운영 에이전트용)
    },
    var.additional_metadata
  )

  # 시작 스크립트 - 값이 비어있지 않을 때만 적용
  metadata_startup_script = var.startup_script != "" ? var.startup_script : null

  # 네트워크 설정
  # VPC 네트워크 및 서브넷 지정, 외부 IP 할당
  network_interface {
    network = var.network
    subnetwork = var.subnetwork != "" ? var.subnetwork : null

    # 외부 IP 할당 (고정 IP 지원)
    access_config {
      nat_ip = var.static_ip  # 여기에 고정 IP 설정 추가
    }
  }

  # 서비스 계정 설정
  # VM이 다른 GCP 리소스에 액세스하는 데 사용되는 권한
  service_account {
    email  = var.service_account_email != null ? var.service_account_email : null # null이면 프로젝트의 기본 서비스 계정 사용
    scopes = var.service_account_scopes                                           # 필요한 API 액세스 범위
  }

  tags = var.tags
  labels = var.labels # 리소스 관리 및 비용 추적

  # 인스턴스 템플릿 관리 설정
  # 새 템플릿이 먼저 생성된 후 이전 템플릿 삭제 (무중단 업데이트 지원)
  lifecycle {
    create_before_destroy = true
  }
}

# 인스턴스 상태 확인 정의
# MIG에서 비정상 인스턴스를 감지하고 자동 복구하는 데 사용
resource "google_compute_health_check" "this" {
  name                = "${var.instance_name}-hc"
  project             = var.project_id
  check_interval_sec  = var.check_interval_sec  # 확인 간격
  timeout_sec         = var.timeout_sec         # 응답 제한 시간
  healthy_threshold   = var.healthy_threshold   # 정상으로 판단할 연속 성공 횟수
  unhealthy_threshold = var.unhealthy_threshold # 비정상으로 판단할 연속 실패 횟수

  # SSH 포트 확인
  # VM이 정상 작동하는지 확인하는 가장 기본적인 방법
  tcp_health_check {
    port = var.health_check_port # 일반적으로 SSH 포트(22)
  }

  # 안전한 삭제를 위한 lifecycle 설정
  lifecycle {
    create_before_destroy = true
  }
}

# 영역(Zonal) 관리형 인스턴스 그룹으로 변경
resource "google_compute_instance_group_manager" "this" {
  name               = "${var.instance_name}-mig"
  project            = var.project_id
  zone               = var.zone
  base_instance_name = var.instance_name

  # 명시적 의존성 추가 - destroy 순서 보장
  depends_on = [
    google_compute_instance_template.this,
    google_compute_health_check.this
  ]

  # 인스턴스 버전 설정
  # 사용할 템플릿 지정
  version {
    instance_template = google_compute_instance_template.this.id
  }

  # 총 인스턴스 수
  # 일반적으로 L4 MIG는 1, 다른 MIG는 0으로 시작
  target_size = var.target_size

  # 인스턴스 생성 완료 대기 여부
  wait_for_instances = var.wait_for_instances

  # 업데이트 정책
  # 템플릿 변경 시 인스턴스가 업데이트되는 방식 정의
  update_policy {
    type                           = var.update_type
    minimal_action                 = var.minimal_action
    most_disruptive_allowed_action = var.most_disruptive_allowed_action
    max_surge_fixed                = var.max_surge_fixed
    max_unavailable_fixed          = var.max_unavailable_fixed_zonal
    replacement_method             = "RECREATE"
  }

  # 로드 밸런서 포트 매핑
  # 인스턴스가 로드 밸런서에 연결될 때 사용
  named_port {
    name = "http"
    port = var.http_port
  }

  named_port {
    name = "https"
    port = var.https_port
  }

  # 자동 복구 정책
  auto_healing_policies {
    health_check      = google_compute_health_check.this.id
    initial_delay_sec = var.initial_delay_sec # 초기 대기 시간 (VM 부팅 완료 대기)
  }

  # 변경 무시 설정 및 삭제 순서 제어
  lifecycle {
    ignore_changes = [
      # 외부에서 set-instance-template 으로 바꾸는 필드
      version[0].instance_template,
      target_size,
    ]
    # MIG를 먼저 삭제하도록 보장
    create_before_destroy = false
  }

  dynamic "named_port" {
    for_each = var.additional_named_ports
    content {
      name = named_port.value.name
      port = named_port.value.port
    }
  }
}
