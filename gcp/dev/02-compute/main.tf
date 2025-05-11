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

  # 리전 설정 - 대만(타이완) 리전 사용
  region = "asia-east1"

  # 가용 영역 설정 - 대만 리전의 a, b, c 영역 사용 (고가용성 확보)
  # zones = ["asia-east1-a", "asia-east1-b", "asia-east1-c"]
  # 가용 영역이 pd 와 같은곳에 있어야 함...
  zones = ["asia-east1-a"]

  # 인스턴스 이름 - "l4-spot"으로 L4 GPU 스팟 인스턴스임을 표시
  instance_name = "l4-spot"

  # 머신 타입 - g2-standard-4 (vCPU 4개, 메모리 16GB의 G2 시리즈)
  machine_type = "g2-standard-4"

  # 스팟 인스턴스 사용 여부 - true로 설정하여 비용 절감 (단, 리소스 회수 가능성 있음)
  spot = true

  # 소스 이미지 변수 설정
  # 커스텀 이미지 사용 설정 (CI/CD에서 동적으로 변경할 수 있음)
  

  # 소스 이미지 - 커스텀 이미지가 있으면 사용, 없으면 기본 이미지 사용
  source_image         = ""
  source_image_family  = "pytorch-latest-cu121-ubuntu-2204-py310"  # PyTorch CUDA 12.1, Ubuntu 22.04, Python 3.10
  source_image_project = "deeplearning-platform-release"

  # 디스크 크기 - 50GB 설정 (OS와 기본 패키지만 설치)
  disk_size_gb = 100

  # 디스크 타입 - SSD 사용 (빠른 I/O 성능 제공)
  disk_type = "pd-balanced"

  # GPU 타입 - NVIDIA L4 (딥러닝 및 추론 작업에 최적화된 GPU)
  gpu_type = "nvidia-l4"

  # GPU 개수 - 인스턴스당 1개의 L4 GPU 할당
  gpu_count = 1

  # 추가 메타데이터 설정
  additional_metadata = {
    "install-nvidia-driver" = "True"
    "custom-image-used"     = "false"
  }

  # 네트워크 설정 - 기본 네트워크 사용
  network = "default"

  # 서브네트워크 설정 - 빈 문자열로 기본 서브네트워크 사용
  subnetwork = ""

  # 고정 IP 주소 설정 추가
  # static_ip = google_compute_address.l4_static_ip.address

  # 서비스 계정 이메일 - null 설정으로 프로젝트의 기본 서비스 계정 사용
  service_account_email = null

  # 서비스 계정 접근 범위 - 클라우드 플랫폼 전체 접근 권한 부여
  service_account_scopes = [
    "https://www.googleapis.com/auth/cloud-platform"
  ]

  # 시작 스크립트 - 인스턴스 생성 시 실행할 스크립트 (local 변수에서 내용 참조)
  startup_script = local.final_startup_script

  tags = ["l4-spot"]

  labels = local.common_labels

  # 로드 밸런서 및 헬스 체크 설정
  # HTTP 포트 설정 - 기본 HTTP 통신용
  http_port = 80

  # HTTPS 포트 설정 - 보안 통신용
  https_port = 443

  # 헬스 체크 포트 - SSH 포트(22)로 인스턴스 상태 점검
  health_check_port = 22

  # 초기 지연 시간 - 인스턴스 생성 후 헬스 체크 시작까지 300초(5분) 대기
  # (GPU 드라이버 설치 및 시작 스크립트 실행 시간 고려)
  initial_delay_sec = 300

  # 체크 간격 - 10초마다 헬스 체크 수행
  check_interval_sec = 10

  # 타임아웃 - 헬스 체크 응답 대기 시간 5초
  timeout_sec = 5

  # 정상 임계값 - 2회 연속 성공 시 정상으로 판단
  healthy_threshold = 2

  # 비정상 임계값 - 3회 연속 실패 시 비정상으로 판단
  unhealthy_threshold = 3

  # MIG(관리형 인스턴스 그룹) 및 업데이트 정책 설정
  # 목표 인스턴스 수 - 1개의 인스턴스 유지
  target_size = 1

  # 인스턴스 대기 - 인스턴스가 완전히 생성될 때까지 대기
  wait_for_instances = true

  # 업데이트 유형 - PROACTIVE: 변경사항 감지 시 자동으로 인스턴스 업데이트
  update_type = "PROACTIVE"

  # 인스턴스 재분배 유형 - NONE: 인스턴스 재분배 없음 (영역 간 이동 방지)
  instance_redistribution_type = "NONE"

  # 최소 작업 - REPLACE: 변경사항 적용 시 인스턴스 교체
  minimal_action = "REPLACE"

  # 허용되는 가장 파괴적인 작업 - REPLACE: 인스턴스 교체까지 허용
  most_disruptive_allowed_action = "REPLACE"

  # 최대 초과 고정값 - 업데이트 시 0개의 추가 인스턴스 허용 (비용 제어)
  max_surge_fixed = 0

  # 8000, 8080 포트 추가
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

  # 영구 디스크 연결
  add_stateful_disk = true
  
  stateful_disks = [
    {
      device_name = "pd"
      source      = "projects/${local.project_id}/zones/${local.zone}/disks/spot-persistent-disk"
      mode        = "READ_WRITE"
      auto_delete = "NEVER"
    }
  ]
}
