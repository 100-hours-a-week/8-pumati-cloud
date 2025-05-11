# modules/mig/variables.tf
# MIG(Managed Instance Group) 모듈 변수 정의
# 모든 변수는 default 값 없이 정의되어, 사용 시 명시적 지정이 필요합니다.
# 단, 선택적 변수의 경우 description에 권장값을 기재합니다.

# 프로젝트 설정
variable "project_id" { 
  type = string
  description = "GCP 프로젝트 ID"
}

variable "region" { 
  type = string
  description = "인스턴스가 배포될 GCP 리전 (예: asia-northeast3, us-central1)"
}

variable "zones" { 
  type = list(string)
  description = "인스턴스가 배포될 수 있는 영역 목록 (예: ['asia-northeast3-a', 'asia-northeast3-b']). 여러 존을 지정하면 GPU 가용성에 따라 자동으로 존이 선택됨"
}

# 인스턴스 기본 정보
variable "instance_name" { 
  type = string
  description = "인스턴스 기본 이름. MIG 및 템플릿에 사용됨. 프로젝트 내에서 고유해야 함"
}

variable "machine_type" { 
  type = string
  description = "인스턴스 머신 타입. GPU 유형에 맞는 머신 타입 선택 필요 (L4: g2-standard-4, T4/P100: n1-standard-4 권장)"
}

variable "spot" { 
  type = bool
  description = "스팟(선점형) 인스턴스 사용 여부. 비용 절감을 위해 true 권장, 안정성이 중요하면 false"
}

# 디스크 설정
variable "source_image" { 
  type = string
  description = "부팅 디스크 이미지 전체 경로 (ex: projects/my-project/global/images/my-image). source_image_family와 함께 사용 시 source_image가 우선함"
  default = null
}

variable "disk_size_gb" { 
  type = number
  description = "부팅 디스크 크기(GB). GPU 워크로드는 최소 100GB 권장"
}

variable "disk_type" { 
  type = string
  description = "부팅 디스크 유형. 성능을 위해 'pd-ssd' 권장. 비용 절감 필요 시 'pd-standard'"
}

# 이미지 패밀리 추가
variable "source_image_family" { 
  type = string
  description = "부팅 디스크 이미지 패밀리 (ex: pytorch-latest-gpu). source_image가 설정된 경우 무시됨"
  default = null
}

# 이미지 프로젝트 추가
variable "source_image_project" { 
  type = string
  description = "부팅 디스크 이미지가 속한 프로젝트 (ex: deeplearning-platform-release). source_image가 설정된 경우 무시됨"
  default = null
}

# GPU 설정
variable "gpu_type" { 
  type = string
  description = "GPU 유형. 'nvidia-l4', 'nvidia-tesla-t4', 'nvidia-tesla-p100' 등. 머신 타입에 맞게 선택 필요"
}

variable "gpu_count" { 
  type = number
  description = "GPU 개수. 일반적으로 1. 모듈별로 적절히 설정 필요"
}

# 메타데이터 및 추가 설정
variable "additional_metadata" { 
  type = map(string)
  description = "추가 메타데이터 (키-값 쌍). 기본값 = {}"
}

# 네트워크 설정
variable "network" { 
  type = string
  description = "인스턴스가 연결될 VPC 네트워크 이름. 일반적으로 'default' 또는 기존 VPC 네트워크"
}

variable "subnetwork" { 
  type = string
  description = "인스턴스가 연결될 서브넷워크 이름 (선택사항). 비워두면 기본 서브넷 사용. 기본값 = ''"
}

# 서비스 계정 설정
variable "service_account_email" { 
  type = string
  description = "인스턴스에 연결할 서비스 계정 이메일. 비워두면 프로젝트의 기본 컴퓨트 서비스 계정 사용"
}

variable "service_account_scopes" { 
  type = list(string)
  description = "서비스 계정에 부여할 권한 범위 목록. 권장값: ['https://www.googleapis.com/auth/cloud-platform']"
}

# 스크립트 및 태그
variable "startup_script" { 
  type = string
  description = "인스턴스 시작 시 실행할 스크립트. 커스텀 이미지 사용 시 빈 문자열 또는 null 설정 가능"
}

variable "tags" { 
  type = list(string)
  description = "인스턴스에 적용할 네트워크 태그. 기본값 = []"
}

variable "labels" { 
  type = map(string)
  description = "인스턴스에 적용할 라벨 (키-값 쌍). 리소스 관리 및 비용 추적에 사용. 기본값 = {}"
}

# 로드 밸런서 포트 설정
variable "http_port" { 
  type = number
  description = "HTTP 트래픽을 위한 포트. 기본값 = 80"
}

variable "https_port" { 
  type = number
  description = "HTTPS 트래픽을 위한 포트. 기본값 = 443"
}

# 헬스 체크 설정
variable "health_check_port" { 
  type = number
  description = "상태 확인에 사용할 포트. 일반적으로 SSH 포트(22) 사용. 기본값 = 22"
}

variable "initial_delay_sec" { 
  type = number
  description = "자동 복구 전 초기 지연 시간(초). 인스턴스 부팅 및 초기화에 충분한 시간 필요. 기본값 = 300"
}

variable "check_interval_sec" { 
  type = number
  description = "상태 확인 간격(초). 기본값 = 10"
}

variable "timeout_sec" { 
  type = number
  description = "상태 확인 타임아웃(초). 기본값 = 5"
}

variable "healthy_threshold" { 
  type = number
  description = "정상 상태로 간주하기 위한 연속 성공 횟수. 기본값 = 2"
}

variable "unhealthy_threshold" { 
  type = number
  description = "비정상 상태로 간주하기 위한 연속 실패 횟수. 기본값 = 3"
}

# MIG 및 업데이트 정책 설정
variable "target_size" { 
  type = number
  description = "생성할 인스턴스 수. L4는 1, T4/P100 백업 MIG는 0으로 시작. 기본값 = 0"
}

variable "wait_for_instances" { 
  type = bool
  description = "인스턴스 생성 완료 대기 여부. true로 설정하면 모든 인스턴스가 생성될 때까지 Terraform 실행이 대기함. 기본값 = true"
}

variable "update_type" { 
  type = string
  description = "MIG 업데이트 정책 유형. PROACTIVE: 템플릿 변경 시 적극적 업데이트, OPPORTUNISTIC: 다른 이유로 재생성 시에만 업데이트. 기본값 = PROACTIVE"
}

variable "instance_redistribution_type" { 
  type = string
  description = "인스턴스 재분배 유형. NONE: 존 간 이동 방지, PROACTIVE: 존 간 밸런싱. 기본값 = NONE"
}

variable "minimal_action" { 
  type = string
  description = "업데이트 시 최소 액션. REPLACE: 인스턴스 교체. 기본값 = REPLACE"
}

variable "most_disruptive_allowed_action" { 
  type = string
  description = "업데이트 시 허용되는 가장 파괴적인 액션. REPLACE, RESTART 등. 기본값 = REPLACE"
}

variable "max_surge_fixed" { 
  type = number
  description = "업데이트 중 추가할 수 있는 최대 인스턴스 수. 할당량 문제 방지를 위해 0 권장. 기본값 = 0"
}

# 스테이트풀 디스크 설정
variable "stateful_disks" {
  type = list(object({
    device_name = string       # 인스턴스 내에서 사용할 디바이스 이름
    source      = string       # 기존 디스크의 전체 경로
    mode        = string       # READ_ONLY 또는 READ_WRITE
    auto_delete = string       # NEVER 또는 ON_PERMANENT_INSTANCE_DELETION
  }))
  description = "MIG에 연결할 스테이트풀 디스크 목록 (영구 디스크). 설정하지 않으면 스테이트리스 디스크만 사용"
  default     = []
}

variable "static_ip" {
  type        = string
  description = "인스턴스에 할당할 고정 IP 주소"
  default     = null
}

variable "additional_named_ports" {
  type = list(object({
    name = string
    port = number
  }))
  description = "추가 포트 설정 (이름과 포트 번호)"
  default     = []
}

variable "add_stateful_disk" {
  type        = bool
  description = "인스턴스 템플릿에 stateful 디스크 슬롯을 추가할지 여부"
  default     = false
}

variable "persistent_disk_name" {
  type        = string
  description = "스테이트풀로 연결할 영구 디스크 이름"
}

variable "zone" {
   type        = string
   description = "인스턴스가 배포될 영역 (zonal 리소스 참조용)"
   # 00-common 또는 01-static에서 받아올 수 있습니다.
   # 01-static의 outputs에서 zone 값을 가져오도록 설정 필요
}