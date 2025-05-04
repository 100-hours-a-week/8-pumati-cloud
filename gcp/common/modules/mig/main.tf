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

  # 부팅 디스크 설정
  # 이미지, 크기, 유형 등 지정
  disk {
    source_image = var.source_image  # GPU 작업에 최적화된 이미지 권장
    auto_delete  = true  # 인스턴스 삭제 시 디스크도 자동 삭제
    boot         = true
    disk_size_gb = var.disk_size_gb  # GPU 워크로드는 100GB 이상 권장
    disk_type    = var.disk_type     # pd-ssd가 성능 향상에 도움
  }

  # GPU 설정
  # 인스턴스에 할당할 GPU 유형과 개수
  guest_accelerator {
    type  = var.gpu_type  # "nvidia-l4", "nvidia-tesla-t4", "nvidia-tesla-p100" 등
    count = var.gpu_count  # 일반적으로 1
  }

  # 메타데이터와 시작 스크립트에 운영 에이전트 설치 코드 추가
  metadata = merge(
    { 
      "install-gpu-driver" = "true",  # GPU 드라이버 자동 설치 활성화
      "enable-osconfig" = "true"      # OS 구성 관리 활성화 (운영 에이전트용)
    },
    var.additional_metadata
  )

  # 시작 스크립트에 운영 에이전트 설치 명령 추가
  metadata_startup_script = <<EOF
${var.startup_script}

# 운영 에이전트 설치
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
sudo bash add-google-cloud-ops-agent-repo.sh --also-install

# GPU 메트릭 수집을 위한 추가 설정
cat <<EOC | sudo tee /etc/google-cloud-ops-agent/config.yaml
metrics:
  receivers:
    nvidia_gpu:
      type: nvidia_gpu
      collection_interval: 60s
  service:
    pipelines:
      default_pipeline:
        receivers:
          - nvidia_gpu
EOC

# 운영 에이전트 재시작
sudo service google-cloud-ops-agent restart
EOF

  # 네트워크 설정
  # VPC 네트워크 및 서브넷 지정, 외부 IP 할당
  network_interface {
    network = var.network  # VPC 네트워크 이름
    
    # 서브넷 지정 (선택사항)
    # 빈 문자열이 아닌 경우에만 서브넷워크 속성 적용
    subnetwork = var.subnetwork != "" ? var.subnetwork : null
    
    # 외부 IP 할당 (선택적으로 고정 IP 할당도 가능)
    access_config {}
  }

  # 서비스 계정 설정
  # VM이 다른 GCP 리소스에 액세스하는 데 사용되는 권한
  service_account {
    email  = var.service_account_email != null ? var.service_account_email : null   # null이면 프로젝트의 기본 서비스 계정 사용
    scopes = var.service_account_scopes  # 필요한 API 액세스 범위
  }

  tags                    = var.tags            # 방화벽 규칙에 사용
  labels                  = var.labels          # 리소스 관리 및 비용 추적

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
  check_interval_sec  = var.check_interval_sec   # 확인 간격
  timeout_sec         = var.timeout_sec          # 응답 제한 시간
  healthy_threshold   = var.healthy_threshold    # 정상으로 판단할 연속 성공 횟수
  unhealthy_threshold = var.unhealthy_threshold  # 비정상으로 판단할 연속 실패 횟수

  # SSH 포트 확인
  # VM이 정상 작동하는지 확인하는 가장 기본적인 방법
  tcp_health_check {
    port = var.health_check_port  # 일반적으로 SSH 포트(22)
  }
}

# 리전 관리형 인스턴스 그룹
# 여러 존에 걸쳐 인스턴스를 생성하고 관리
resource "google_compute_region_instance_group_manager" "this" {
  name               = "${var.instance_name}-mig"
  project            = var.project_id
  region             = var.region
  base_instance_name = var.instance_name

  # 존 배포 정책 - 여러 존 지정 가능 (자동 존 전환)
  # GCP는 지정된 존 중에서 용량이 있는 존에 인스턴스를 자동 배치
  distribution_policy_zones = var.zones

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
    type                           = var.update_type  # PROACTIVE: 자동 업데이트
    instance_redistribution_type   = var.instance_redistribution_type  # NONE: 존 간 재배포 안 함
    minimal_action                 = var.minimal_action  # REPLACE: 완전히 교체
    most_disruptive_allowed_action = var.most_disruptive_allowed_action  # REPLACE: 필요시 전체 교체 허용
    max_surge_fixed                = var.max_surge_fixed  # 0: 새 인스턴스 생성 전 기존 인스턴스 제거
    max_unavailable_fixed          = length(var.zones)  # 존 수에 맞게 설정 (2개 이상의 존 사용 시)
    replacement_method             = "SUBSTITUTE"  # 하드코딩: GPU 할당량 부족 시 대체 시도
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
  # 비정상 인스턴스를 감지하고 자동으로 대체
  auto_healing_policies {
    health_check      = google_compute_health_check.this.id
    initial_delay_sec = var.initial_delay_sec  # 초기 대기 시간 (VM 부팅 완료 대기)
  }

  # 변경 무시 설정
  # 외부 스크립트가 target_size를 동적으로 조절할 때 Terraform이 덮어쓰지 않도록 함
  lifecycle {
    ignore_changes = [
      # 외부에서 set-instance-template 으로 바꾸는 필드
      version[0].instance_template,
      target_size,
    ]
  }
}