# modules/persistent-disk/variables.tf - 영구 디스크 모듈 변수

# 프로젝트 관련 필수 변수
variable "project_id" {
  description = "GCP 프로젝트 ID"
  type        = string
}

variable "zone" {
  description = "디스크가 위치할 영역"
  type        = string
}

# 디스크 관련 변수
variable "disk_name" {
  description = "디스크 이름"
  type        = string
}

variable "description" {
  description = "디스크 설명"
  type        = string
  default     = ""
}

variable "disk_type" {
  description = "디스크 유형 (pd-standard, pd-balanced, pd-ssd)"
  type        = string
  default     = "pd-standard"
}

variable "disk_size" {
  description = "디스크 크기(GB)"
  type        = number
  default     = 10
}

variable "labels" {
  description = "디스크에 적용할 라벨"
  type        = map(string)
  default     = {}
}

# 선택적 파라미터
variable "snapshot_name" {
  description = "디스크 생성에 사용할 스냅샷 이름 (선택 사항)"
  type        = string
  default     = ""
}

variable "source_image" {
  description = "디스크 생성에 사용할 이미지 (선택 사항)"
  type        = string
  default     = ""
}

variable "physical_block_size_bytes" {
  description = "물리적 블록 크기(바이트) - 4096 또는 16384"
  type        = number
  default     = 4096
}

variable "provisioned_iops" {
  description = "pd-extreme 디스크 유형 사용 시 프로비저닝된 IOPS"
  type        = number
  default     = 10000
}
