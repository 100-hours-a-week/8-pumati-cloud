# ------------------------------------------------------------
# 프로젝트 변수
# ------------------------------------------------------------
variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "environment" {
  description = "환경 (예: dev, prod)"
  type        = string
}

variable "tags" {
  description = "리소스 태그"
  type        = map(string)
  default     = {}
}

# ------------------------------------------------------------
# 인스턴스 변수
# ------------------------------------------------------------
variable "instance_role" {
  description = "인스턴스 역할 (frontend, backend, jenkins)"
  type        = string
}

variable "instance_type" {
  description = "인스턴스 유형 (예: t3.micro)"
  type        = string
}

variable "instance_ami" {
  description = "인스턴스 AMI ID"
  type        = string
}

variable "instance_key_name" {
  description = "인스턴스 키페어 이름"
  type        = string
}

variable "root_volume_size" {
  description = "루트 볼륨 크기 (GB)"
  type        = number
}

variable "root_volume_type" {
  description = "루트 볼륨 타입 (gp2, gp3, io1 등)"
  type        = string
}

variable "subnet_id" {
  description = "서브넷 ID"
  type        = string
}

# ------------------------------------------------------------
# 보안 그룹 변수
# ------------------------------------------------------------
variable "frontend_security_group_id" {
  description = "프론트엔드 인스턴스에 연결할 보안 그룹 ID"
  type        = string
  default     = ""
}

variable "backend_security_group_id" {
  description = "백엔드 인스턴스에 연결할 보안 그룹 ID"
  type        = string
  default     = ""
}

variable "jenkins_security_group_id" {
  description = "Jenkins 인스턴스에 연결할 보안 그룹 ID"
  type        = string
  default     = ""
}

# ------------------------------------------------------------
# IAM 변수
# ------------------------------------------------------------
variable "iam_instance_profile" {
  description = "IAM 인스턴스 프로파일 이름"
  type        = string
  default     = ""
}
