variable "project_name" {
  description = "프로젝트 이름"
  type = string
}

variable "environment" {
  description = "환경 (예: dev, prod)"
  type = string
}

variable "service_name" {
  description = "서비스 이름(예: frontend, service, db)"
  type = string
}

# 인스턴스 구성
variable "instance_ami" {
  description = "인스턴스에 사용할 AMI ID"
  type = string
}

variable "instance_type" {
  description = "인스턴스 타입 (예: t3.micro)"
  type = string
}

variable "instance_key_name" {
  description = "SSH 키 이름"
  type = string
}

variable "user_data_base64" {
  description = "인스턴스 부팅 시 실행할 스크립트"
  type = string
}

variable "iam_instance_profile" {
  description = "IAM 인스턴스 프로파일 이름"
  type = string
}

# 보안 및 네트워크
variable "security_group_ids" {
  description = "보안 그룹 ID 목록"
  type = list(string)
}

variable "subnet_id" {
  description = "서브넷 ID"
  type = string
}

variable "target_group_arns" {
  description = "대상 그룹 ARN 목록"
  type = list(string)
}

# Auto Scaling 설정
variable "min_size" {
  type = number
}

variable "max_size" {
  type = number
}

variable "desired_capacity" {
  type = number
}

# 루트 볼륨 설정
variable "root_volume_size" {
  description = "루트 볼륨 크기"
  type = number
}

variable "root_volume_type" {
  description = "루트 볼륨 타입 (예: gp3)"
  type = string
}

# 헬스 체크 설정
variable "health_check_type" {
  description = "헬스 체크 유형 (예: EC2, ELB)"
  type = string
}

variable "health_check_grace_period" {
  description = "헬스 체크 유형 (예: EC2, ELB)"
  type = number
}

variable "tags" {
  description = "공통 태그"
  type = map(string)
}
