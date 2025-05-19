module "l4_compute" {
  # 컴퓨트 인스턴스 모듈 소스 경로 사용
  source = "../../common/modules/compute"

  # 프로젝트 관련 기본 설정
  project_id = local.project_id
  region = local.region
  zone = local.zone

  # 인스턴스 기본 설정
  instance_name = "l4-gpu-instance"
  machine_type = "g2-standard-4"
  spot = true  # 스팟 인스턴스 사용 (비용 절감)

  # 디스크 설정
  boot_disk_image = "projects/deeplearning-platform-release/global/images/family/pytorch-latest-cu121-ubuntu-2204-py310"
  boot_disk_size = 50
  boot_disk_type = "pd-balanced"  # SSD에서 밸런스드로 변경

  # GPU 설정
  gpu_type = "nvidia-l4"
  gpu_count = 1

  # 네트워크 설정
  network = "default"
  static_ip_name = "l4-gpu-static-ip"

  # 서비스 계정 설정
  service_account_email = ""  # 빈 문자열로 설정하면 프로젝트의 기본 서비스 계정 사용
  service_account_scopes = [
    "https://www.googleapis.com/auth/cloud-platform"
  ]

  # 메타데이터 및 스크립트 설정
  startup_script = local.final_startup_script
  additional_metadata = {
    "install-nvidia-driver" = "True"
    "custom-image-used" = "false"  # 커스텀 이미지 사용 안함
  }

  # 태그 및 라벨 설정
  tags = local.common_tags
  labels = {
    "custom-image" = "no"  # 커스텀 이미지 사용 안함
    "environment" = local.environment
  }

  # 방화벽 설정
  firewall_rules = {
    name = "allow-l4-gpu-instance"
    protocol = "tcp"
    ports = ["22", "80", "443", "8000", "8080"]  # 8080 포트 추가
    source_ranges = ["0.0.0.0/0"]
  }
}


