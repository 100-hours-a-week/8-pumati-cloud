variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "environment" {
  description = "환경 (예: dev, prod)"
  type        = string
}

variable "service_name" {
  description = "서비스 이름(예: frontend, service, db)"
  type = string
}

variable "instance_ami" {
  description = "EC2 인스턴스에 사용할 AMI ID"
  type        = string
}

variable "instance_type" {
  description = "인스턴스 타입 (예: t3.micro)"
  type        = string
}

variable "instance_key_name" {
  description = "SSH 키 이름"
  type        = string
}

variable "subnet_id" {
  description = "서브넷 ID"
  type        = string
}

variable "security_group_ids" {
  description = "보안 그룹 ID 목록"
  type        = list(string)
}

variable "source_dest_check" {
  description = "소스/대상 체크 설정 (NAT 인스턴스의 경우 false로 설정)"
  type        = bool
  default     = true
}
variable "iam_instance_profile" {
  description = "IAM 인스턴스 프로파일 이름"
  type        = string
  default     = ""
}

variable "root_volume_size" {
  description = "루트 볼륨 크기 (GB)"
  type        = number
}

variable "root_volume_type" {
  description = "루트 볼륨 타입 (예: gp3)"
  type        = string
}

variable "user_data" {
  description = "User data 스크립트 (startup script)"
  type        = string
  default     = ""
}

variable "enable_monitoring" {
  description = "CloudWatch 상세 모니터링 활성화 여부"
  type        = bool
}

variable "disable_api_termination" {
  description = "인스턴스 종료 보호 설정"
  type        = bool
}

variable "shutdown_behavior" {
  description = "인스턴스 내부 종료 시 동작 (stop 또는 terminate)"
  type        = string
}

variable "enable_eip" {
  description = "EIP를 할당할지 여부"
  type        = bool
}

variable "tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}