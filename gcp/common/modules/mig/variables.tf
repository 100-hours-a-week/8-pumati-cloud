# modules/mig/variables.tf - MIG 모듈 변수 정의

# [필수] 기본 인스턴스 식별자 이름
# MIG 및 템플릿에 사용되는 이름으로, 프로젝트 내에서 고유해야 함
variable "instance_name" {
  description = "인스턴스 기본 이름 (MIG 및 템플릿에 사용됨)"
  type        = string
}

# [필수] 인스턴스 머신 타입
# GPU가 지원되는 타입을 선택해야 함 (예: n1-standard-4)
variable "machine_type" {
  description = "인스턴스 머신 타입 (예: n1-standard-4)"
  type        = string
}

# [필수] GCP 프로젝트 ID
# 모든 리소스가 이 프로젝트에 생성됨
variable "project_id" {
  description = "GCP 프로젝트 ID"
  type        = string
}

# [필수] 인스턴스가 배포될 GCP 리전
# 리전 선택 시 GPU 가용성 고려 필요
variable "region" {
  description = "인스턴스가 배포될 GCP 리전"
  type        = string
}

# 인스턴스가 배포될 특정 영역 (선택사항)
# 특정 존 지정이 필요한 경우 사용 (예: asia-northeast3-a)
variable "zone" {
  description = "인스턴스가 배포될 GCP 영역 (zone)"
  type        = string
  # 권장값: 비워두면 리전 내에서 자동 선택
}

# 스팟(선점형) 인스턴스 사용 여부
# 비용 절감을 위해 true 권장, 안정성이 중요하면 false
variable "spot" {
  description = "스팟(선점형) 인스턴스 사용 여부"
  type        = bool
  # 권장값: true (비용 최적화)
}

# 연결할 네트워크 이름
# VPC 네트워크 이름 지정
variable "network" {
  description = "인스턴스가 연결될 네트워크"
  type        = string
  # 권장값: 'default' 또는 기존 VPC 네트워크 이름
}

# 시작 스크립트 (선택사항)
# 인스턴스 시작 시 실행할 명령어 (소프트웨어 설치 등)
variable "startup_script" {
  description = "인스턴스 시작 시 실행할 스크립트"
  type        = string
  # 권장값: 필요한 도구 설치 스크립트 (빈 문자열도 가능)
}

# 서비스 계정 이메일 (선택사항)
# 비어있으면 프로젝트의 기본 컴퓨트 서비스 계정 사용
variable "service_account_email" {
  description = "인스턴스에 연결할 서비스 계정 이메일"
  type        = string
  # 권장값: 비워두면 프로젝트 기본값 사용
}

# 서비스 계정 권한 범위
# 인스턴스가 GCP API에 접근하기 위한 권한 범위
variable "service_account_scopes" {
  description = "서비스 계정에 부여할 권한 범위 목록"
  type        = list(string)
  # 권장값: ["https://www.googleapis.com/auth/cloud-platform"]
}

# 네트워크 태그 (선택사항)
# 방화벽 규칙 등에 사용
variable "tags" {
  description = "인스턴스에 적용할 네트워크 태그"
  type        = list(string)
  # 권장값: ["gpu", "worker"] 등 용도에 맞게 지정
}

# 리소스 라벨 (선택사항)
# 리소스 관리 및 비용 추적 등에 사용
variable "labels" {
  description = "인스턴스에 적용할 라벨 (키-값 쌍)"
  type        = map(string)
  # 권장값: {"environment" = "prod", "app" = "gpu-worker"} 등
}

# 추가 메타데이터 (선택사항)
# 인스턴스 메타데이터로 추가할 키-값 쌍
variable "additional_metadata" {
  description = "인스턴스에 추가할 메타데이터 (키-값 쌍)"
  type        = map(string)
  # 권장값: {"enable-oslogin" = "TRUE"} 등 필요에 따라 지정
}

# 헬스 체크 설정 - 초기 지연 시간(초)
variable "initial_delay_sec" {
  description = "자동 복구 전 초기 지연 시간(초)"
  type        = number
  default     = 300  # 5분 - VM 시작 및 GPU 드라이버 설치 시간 고려
}

# 헬스 체크 설정 - 확인 간격(초)
variable "check_interval_sec" {
  description = "상태 확인 간격(초)"
  type        = number
  default     = 5
}

# 헬스 체크 설정 - 타임아웃(초)
variable "timeout_sec" {
  description = "상태 확인 타임아웃(초)"
  type        = number
  default     = 5
}

# 헬스 체크 설정 - 정상 임계값
variable "healthy_threshold" {
  description = "정상 상태로 간주하기 위한 연속 성공 횟수"
  type        = number
  default     = 2
}

# 헬스 체크 설정 - 비정상 임계값
variable "unhealthy_threshold" {
  description = "비정상 상태로 간주하기 위한 연속 실패 횟수"
  type        = number
  default     = 2
}

# 헬스 체크 포트
variable "health_check_port" {
  description = "상태 확인에 사용할 포트"
  type        = number
  default     = 22  # SSH 포트
}

# HTTP 포트 설정
variable "http_port" {
  description = "HTTP 트래픽을 위한 포트"
  type        = number
  default     = 80
}

# HTTPS 포트 설정
variable "https_port" {
  description = "HTTPS 트래픽을 위한 포트"
  type        = number
  default     = 443
}

# 업데이트 정책 - 유형
variable "update_type" {
  description = "MIG 업데이트 정책 유형"
  type        = string
  default     = "PROACTIVE"  # 템플릿 변경 시 인스턴스를 적극적으로 업데이트
}

# 업데이트 정책 - 인스턴스 재분배 유형
variable "instance_redistribution_type" {
  description = "인스턴스 재분배 유형"
  type        = string
  default     = "NONE"  # 인스턴스 재분배 안 함 (영역 간 이동 방지)
}

# 업데이트 정책 - 최소 액션
variable "minimal_action" {
  description = "업데이트 시 최소 액션"
  type        = string
  default     = "REPLACE"  # 인스턴스를 교체하는 방식으로 업데이트
}

# 업데이트 정책 - 가장 파괴적인 허용 액션
variable "most_disruptive_allowed_action" {
  description = "업데이트 시 허용되는 가장 파괴적인 액션"
  type        = string
  default     = "REPLACE"  # 인스턴스 교체 허용
}

# 업데이트 정책 - 최대 동시 추가 인스턴스 수
variable "max_surge_fixed" {
  description = "업데이트 중 추가할 수 있는 최대 인스턴스 수"
  type        = number
  default     = 0  # 새 인스턴스 생성 전 기존 인스턴스 제거
}

# 업데이트 정책 - 최대 동시 이용 불가 인스턴스 수
variable "max_unavailable_fixed" {
  description = "업데이트 중 이용 불가능한 상태가 될 수 있는 최대 인스턴스 수"
  type        = number
  default     = 1  # 최대 1개 인스턴스가 사용 불가능한 상태 허용
}

# 업데이트 정책 - 대체 방법
variable "replacement_method" {
  description = "인스턴스 대체 방법"
  type        = string
  default     = "SUBSTITUTE"  # GPU 할당량 문제 시 다른 템플릿으로 대체 가능
}

# 인스턴스 생성 완료 대기 여부
variable "wait_for_instances" {
  description = "인스턴스 생성 완료 대기 여부"
  type        = bool
  default     = true  # 인스턴스 생성 완료 후 Terraform 실행 완료
}
