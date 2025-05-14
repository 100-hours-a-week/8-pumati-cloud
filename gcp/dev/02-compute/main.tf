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

module "l4_mig" {
  # 모듈 소스 경로 - 공통 MIG(관리형 인스턴스 그룹) 모듈 사용
  source = "../../common/modules/mig"

  # GCP 프로젝트 ID - local 변수에서 참조
  project_id = local.project_id

  # 리전 설정 - 대만(타이완) 리전 사용 (모듈 내부에서 일부 네이밍 등에 활용될 수 있음)
  region = "asia-east1"


  # 가용 영역 설정 - Zonal MIG는 단일 zone을 사용합니다.
  # 영구 디스크(PD)와 동일한 영역이어야 합니다.
  # local.zone 변수가 있다면 해당 변수를 사용하는 것이 좋습니다. (예: local.zone)
  # 여기서는 예시로 "asia-east1-a"를 직접 지정합니다.
  zone = "asia-east1-a" # [변경] zones -> zone 으로 변경하고 단일 값 지정

  # 인스턴스 이름 - "l4-spot"으로 L4 GPU 스팟 인스턴스임을 표시
  instance_name = "l4-spot"

  # 머신 타입 - g2-standard-4 (vCPU 4개, 메모리 16GB의 G2 시리즈)
  machine_type = "g2-standard-4"

  # 스팟 인스턴스 사용 여부 - true로 설정하여 비용 절감 (단, 리소스 회수 가능성 있음)
  spot = true

  # 소스 이미지 - 커스텀 이미지가 있으면 사용, 없으면 기본 이미지 사용
  source_image         = "" # 필요시 커스텀 이미지 경로 지정
  source_image_family  = "pytorch-latest-cu121-ubuntu-2204-py310"
  source_image_project = "deeplearning-platform-release"

  # 부팅 디스크 크기 (GPU 인스턴스에는 100GB 미만이면 생성이안됨
  disk_size_gb = 100

  # 부팅 디스크 타입 (성능을 위해 'pd-balanced' 또는 'pd-ssd' 권장)
  disk_type = "pd-balanced"

  # GPU 타입 - NVIDIA L4
  gpu_type = "nvidia-l4"

  # GPU 개수 - 인스턴스당 1개의 L4 GPU 할당
  gpu_count = 1

  # 추가 메타데이터 설정
  additional_metadata = {
    # 모듈에서 "install-gpu-driver" = "true"로 하드코딩 되어 있으므로,
    # 여기서 "install-nvidia-driver"는 덮어쓰지 않거나, 모듈과 키를 통일해야 합니다.
    # 여기서는 모듈의 설정을 따르도록 비워두거나 "install-gpu-driver" 키를 사용합니다.
    "install-gpu-driver" = "True"
    "custom-image-used"  = "false" # 사용자 정의 메타데이터
  }

  # 네트워크 설정 - 기본 네트워크 사용
  network = "default"

  # 서브네트워크 설정 - 빈 문자열로 기본 서브네트워크 사용
  subnetwork = "" # 필요시 특정 서브넷 지정

  # 고정 IP 주소 (필요한 경우 주석 해제 후 사용)
  # static_ip = google_compute_address.l4_static_ip.address
  # [추가] 모듈 변수에서 default가 제거되었으므로 명시적으로 값 전달
  static_ip = null # 고정 IP를 사용하지 않는 경우 null

  # 서비스 계정 이메일 - null 설정으로 프로젝트의 기본 컴퓨트 서비스 계정 사용ㅅ
  # 모듈 변수에 default = null 이 설정되어 있다면 이 줄은 생략 가능
  service_account_email = "terraform@ambient-topic-459110-e6.iam.gserviceaccount.com"

  # 서비스 계정 접근 범위 - 클라우드 플랫폼 전체 접근 권한 부여
  service_account_scopes = [
    "https://www.googleapis.com/auth/cloud-platform"
  ]

  # 시작 스크립트 - 인스턴스 생성 시 실행할 스크립트 (local 변수에서 내용 참조)
  startup_script = local.final_startup_script

  # 네트워크 태그
  tags = ["l4-spot"]

  # 라벨
  labels = local.common_labels

  # 로드 밸런서 및 헬스 체크 설정
  http_port           = 80
  https_port          = 443
  health_check_port   = 22  # SSH 포트로 상태 점검
  initial_delay_sec   = 300 # 부팅 및 스크립트 실행 시간 고려
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  # MIG(관리형 인스턴스 그룹) 및 업데이트 정책 설정
  target_size        = 1    # 1개의 인스턴스 유지
  wait_for_instances = true # 인스턴스 생성 완료 대기

  update_type                  = "PROACTIVE" # 변경사항 자동 업데이트
  instance_redistribution_type = "NONE"      # [추가] Zonal MIG의 경우 "NONE"으로 설정

  minimal_action                 = "REPLACE" # 변경 시 인스턴스 교체
  most_disruptive_allowed_action = "REPLACE" # 최대 허용 작업도 교체
  max_surge_fixed                = 0         # 업데이트 시 추가 인스턴스 없음

  # max_unavailable_fixed_zonal 은 모듈의 기본값(1)을 사용하도록 생략합니다.
  # 필요시 명시적으로 max_unavailable_fixed_zonal = 1 설정 가능
  # [추가] 모듈 변수에서 default가 제거되었으므로 명시적으로 값 전달
  max_unavailable_fixed_zonal = 1 # 단일 인스턴스 Zonal MIG의 경우 1

  # 추가 포트 설정 (예: 애플리케이션 서비스 포트)
  additional_named_ports = [
    {
      name = "port-8000"
      port = 8000
    },
    {
      name = "port-8080"
      port = 8080
    }
  ]
  # [추가] 연결할 영구 디스크(PD)의 이름
  # 이 디스크는 01-static 등에서 미리 생성되어 있어야 하며,
  # 위에서 설정한 'zone'과 동일한 영역에 있어야 합니다.
  # persistent_disk_name   = local.pd_name # 실제 영구 디스크 이름
  # persistent_disk_source = local.spot_pd_self_link

  # [제거] 아래 변수들은 새 모듈 구조에서 사용되지 않음
  # add_stateful_disk = true
  # stateful_disks = [ ... ]
}
