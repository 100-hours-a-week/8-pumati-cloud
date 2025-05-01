# modules/compute/main.tf - 컴퓨팅 인스턴스 모듈 정의

# 스팟 GPU 인스턴스 생성
resource "google_compute_instance" "gpu_instance" {
  # 인스턴스의 기본 식별자 - 고유해야 하며 VM의 이름이 됨
  name         = var.instance_name
  
  # VM의 성능과 하드웨어 규격을 결정 (예: n1-standard-4, e2-highcpu-8 등)
  # GPU 인스턴스의 경우 GPU를 지원하는 머신 타입 선택 필요 (일반적으로 N1 시리즈)
  machine_type = var.machine_type
  
  # 인스턴스가 배포될 지역 내 특정 데이터 센터 위치
  # zone은 항상 리전의 하위 개념 (예: asia-northeast3-a는 asia-northeast3 리전의 a존)
  # 같은 영역에 리소스를 배치하면 네트워크 지연 시간 감소
  zone         = var.zone
  
  # 이 인스턴스가 속한 GCP 프로젝트 ID
  # 여러 프로젝트에서 리소스를 관리할 때 중요
  project      = var.project_id
  
  # 스팟 인스턴스 설정 - 비용 절감을 위한 설정
  # 선점형(스팟) 인스턴스는 일반 인스턴스보다 저렴하지만 Google Cloud가 리소스를 회수할 수 있음
  scheduling {
    # true로 설정 시 선점형 인스턴스로 생성 (var.spot 변수로 제어)
    preemptible        = var.spot
    
    # 스팟 인스턴스는 중지될 수 있으므로 자동 재시작을 비활성화해야 함
    automatic_restart  = false
    
    # "SPOT"은 최신 스팟 인스턴스 모델, "STANDARD"는 일반 인스턴스
    provisioning_model = var.spot ? "SPOT" : "STANDARD"
  }
  
  # 부팅 디스크 설정 - OS와 시스템 파일이 저장되는 디스크
  boot_disk {
    initialize_params {
      # OS 이미지 (예: debian-cloud/debian-11, cos-cloud/cos-stable 등)
      image = var.image
      
      # 디스크 크기(GB) - 워크로드에 따라 조정 필요
      size  = var.boot_disk_size
      
      # 디스크 유형 (pd-standard: 표준 HDD, pd-ssd: SSD 등)
      # GPU 작업을 위해서는 성능을 위해 pd-ssd가 권장됨
      type  = var.boot_disk_type
    }
  }
  
  # GPU 구성 - 딥러닝, 렌더링 등 특화된 컴퓨팅 작업에 필요
  # GPU가 필요한 경우에만 이 구성이 적용됨 (gpu_count > 0인 경우)
  dynamic "guest_accelerator" {
    for_each = var.gpu_count > 0 ? [1] : []
    content {
      # 사용할 GPU 유형 (예: nvidia-tesla-t4, nvidia-tesla-v100 등)
      type  = var.gpu_type
      
      # VM에 연결할 GPU 수량
      count = var.gpu_count
    }
  }
  
  # 메타데이터 설정 - 인스턴스에 대한 추가 정보 제공
  # GPU 사용 시 NVIDIA 드라이버 자동 설치 옵션 활성화
  metadata = merge(
    var.gpu_count > 0 ? { install-gpu-driver = "true" } : {},
    var.additional_metadata
  )
  
  # 네트워크 설정 - VM의 네트워크 연결 구성
  network_interface {
    # 연결할 네트워크 (default는 기본 VPC 네트워크)
    network = var.network
    
    # 외부 IP 할당 구성 - 비어있으면 임시 외부 IP 할당
    access_config {
      # 필요에 따라 고정 IP나 NAT 구성 가능
    }
  }
  
  # 인스턴스 시작 시 실행할 스크립트 - 초기 설정, 소프트웨어 설치 등에 사용
  # 예: CUDA, 딥러닝 프레임워크 설치, 애플리케이션 구성 등
  metadata_startup_script = var.startup_script
  
  # 서비스 계정 설정 - VM이 다른 GCP 서비스에 접근하기 위한 ID
  service_account {
    # 이메일이 비어있으면 프로젝트의 기본 컴퓨트 서비스 계정 사용
    email  = var.service_account_email
    
    # 서비스 계정에 부여할 권한 범위 목록
    scopes = var.service_account_scopes
  }
  
  # 네트워크 태그 - 방화벽 규칙, 라우팅 등을 위한 식별자
  tags = var.tags
  
  # 라벨 - 리소스 관리, 비용 추적, 필터링 등에 사용되는 키-값 쌍
  labels = var.labels
} 