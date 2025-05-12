# modules/mig/variables.tf
# MIG(Managed Instance Group) 모듈 변수 정의
# 모든 변수는 모듈 호출 시 명시적으로 값을 지정해야 합니다.

# --- 프로젝트 및 위치 설정 ---
variable "project_id" {
  type        = string
  description = "GCP 프로젝트 ID입니다."
}

variable "region" {
  type        = string
  description = "인스턴스가 배포될 GCP 리전입니다. (예: 'asia-east1')"
}

variable "zone" {
  type        = string
  description = "Zonal MIG가 배포될 단일 영역입니다. (예: 'asia-east1-a'). 이 변수는 Zonal MIG 설정 시 필수입니다."
}

# --- 인스턴스 기본 정보 ---
variable "instance_name" {
  type        = string
  description = "인스턴스 기본 이름입니다. MIG 및 템플릿에 사용됩니다."
}

variable "machine_type" {
  type        = string
  description = "인스턴스 머신 타입입니다. (예: 'g2-standard-4')"
}

variable "spot" {
  type        = bool
  description = "스팟(선점형) 인스턴스 사용 여부입니다."
}

# --- 부팅 디스크 설정 ---
variable "source_image" {
  type        = string
  description = "부팅 디스크 이미지 전체 경로입니다. (예: 'projects/my-project/global/images/my-image'). source_image_family와 함께 사용 시 source_image가 우선합니다. 둘 중 하나는 필수입니다."
}

variable "source_image_family" {
  type        = string
  description = "부팅 디스크 이미지 패밀리입니다. (예: 'pytorch-latest-gpu'). source_image가 설정된 경우 무시됩니다. 둘 중 하나는 필수입니다."
}

variable "source_image_project" {
  type        = string
  description = "부팅 디스크 이미지가 속한 프로젝트입니다. (예: 'deeplearning-platform-release'). source_image_family 사용 시 필요할 수 있습니다."
}

variable "disk_size_gb" {
  type        = number
  description = "부팅 디스크 크기(GB)입니다."
}

variable "disk_type" {
  type        = string
  description = "부팅 디스크 유형입니다. (예: 'pd-balanced', 'pd-ssd')"
}

# --- 스테이트풀 영구 디스크 설정 (Zonal MIG용 단일 디스크) ---
# variable "persistent_disk_name" {
#   type        = string
#   description = "인스턴스 템플릿의 'pd' device_name에 연결될 기존 영구 디스크의 이름입니다. 이 디스크는 'zone'에 지정된 영역에 이미 존재해야 합니다. 지정하지 않으려면 빈 문자열 \"\"을 전달할 수 있으나, 현재 모듈은 이 값을 사용하여 source를 구성합니다."
# }

# variable "persistent_disk_source" {
#   description = "연결할 기존 영구 디스크의 self_link 또는 ID (인스턴스 템플릿용)"
#   type        = string
# }

# --- GPU 설정 ---
variable "gpu_type" {
  type        = string
  description = "GPU 유형입니다. (예: 'nvidia-l4')"
}

variable "gpu_count" {
  type        = number
  description = "GPU 개수입니다."
}

# --- 네트워크 설정 ---
variable "network" {
  type        = string
  description = "인스턴스가 연결될 VPC 네트워크 이름입니다."
}

variable "subnetwork" {
  type        = string
  description = "인스턴스가 연결될 서브넷워크 이름입니다. 리전 기본 네트워크 사용 시 빈 문자열 \"\" 전달 가능합니다."
}

variable "static_ip" {
  type        = string
  description = "인스턴스에 할당할 고정 외부 IP 주소입니다. 고정 IP를 사용하지 않으려면 null을 전달합니다."
}

# --- 서비스 계정 및 권한 ---
variable "service_account_email" {
  type        = string
  description = "인스턴스에 연결할 서비스 계정 이메일입니다. 프로젝트 기본 서비스 계정 사용 시 null을 전달합니다."
}

variable "service_account_scopes" {
  type        = list(string)
  description = "서비스 계정에 부여할 권한 범위 목록입니다."
}

# --- 스크립트, 태그, 라벨 ---
variable "startup_script" {
  type        = string
  description = "인스턴스 시작 시 실행할 스크립트 내용입니다. 사용하지 않으면 빈 문자열 \"\"을 전달합니다."
}

variable "tags" {
  type        = list(string)
  description = "인스턴스에 적용할 네트워크 태그 목록입니다. 없으면 빈 리스트 [] 전달합니다."
}

variable "labels" {
  type        = map(string)
  description = "인스턴스에 적용할 라벨 (키-값 쌍)입니다. 없으면 빈 맵 {} 전달합니다."
}

# --- MIG 및 업데이트 정책 ---
variable "target_size" {
  type        = number
  description = "MIG에서 유지할 인스턴스 수입니다."
}

variable "wait_for_instances" {
  type        = bool
  description = "인스턴스 생성/업데이트 완료 대기 여부입니다."
}

variable "update_type" {
  type        = string
  description = "MIG 업데이트 정책 유형입니다. (예: 'PROACTIVE', 'OPPORTUNISTIC')"
}

variable "instance_redistribution_type" {
  type        = string
  description = "인스턴스 재분배 유형입니다. Zonal MIG에서는 'NONE'으로 설정합니다."
}

variable "minimal_action" {
  type        = string
  description = "업데이트 시 최소 액션입니다. (예: 'REPLACE', 'RESTART')"
}

variable "most_disruptive_allowed_action" {
  type        = string
  description = "업데이트 시 허용되는 가장 파괴적인 액션입니다. (예: 'REPLACE')"
}

variable "max_surge_fixed" {
  type        = number
  description = "업데이트 중 추가할 수 있는 최대 인스턴스 수입니다."
}

variable "max_unavailable_fixed_zonal" {
  type        = number
  description = "Zonal MIG 업데이트 중 사용할 수 없는 최대 인스턴스 수입니다. (단일 인스턴스 MIG의 경우 일반적으로 1)"
}

# --- 포트 설정 ---
variable "http_port" {
  type        = number
  description = "named_port 'http'에 매핑될 포트 번호입니다."
}

variable "https_port" {
  type        = number
  description = "named_port 'https'에 매핑될 포트 번호입니다."
}

variable "additional_named_ports" {
  type = list(object({
    name = string
    port = number
  }))
  description = "추가로 정의할 named_port 목록입니다. (예: [{name = \"custom\", port = 8080}]). 없으면 빈 리스트 [] 전달합니다."
}

# --- 헬스 체크 ---
variable "health_check_port" {
  type        = number
  description = "TCP 헬스 체크에 사용할 포트 번호입니다."
}

variable "initial_delay_sec" {
  type        = number
  description = "자동 복구 전 초기 지연 시간(초)입니다."
}

variable "check_interval_sec" {
  type        = number
  description = "헬스 체크 간격(초)입니다."
}

variable "timeout_sec" {
  type        = number
  description = "헬스 체크 타임아웃(초)입니다."
}

variable "healthy_threshold" {
  type        = number
  description = "정상 상태로 간주하기 위한 연속 성공 횟수입니다."
}

variable "unhealthy_threshold" {
  type        = number
  description = "비정상 상태로 간주하기 위한 연속 실패 횟수입니다."
}

# --- 더 이상 사용되지 않거나 Zonal MIG 단일 PD 방식에 맞지 않는 변수들 ---
# variable "zones" { ... } # Regional MIG용, 현재 Zonal MIG에서는 "zone" 변수 사용
# variable "stateful_disks" { ... } # 복수 디스크 객체, 현재 단일 "persistent_disk_name" 사용
# variable "add_stateful_disk" { ... } # 내부 로직으로 대체됨

variable "additional_metadata" {
  type        = map(string)
  description = "인스턴스에 추가할 커스텀 메타데이터 (키-값 쌍) 입니다. 없으면 빈 맵 {} 전달합니다."
}