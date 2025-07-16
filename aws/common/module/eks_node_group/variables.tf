variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "environment" {
  description = "환경 이름 (예: dev, prod)"
  type        = string
}

variable "service_name" {
  description = "서비스 이름"
  type        = string
}

variable "tags" {
  description = "리소스에 추가할 태그"
  type        = map(string)
  default     = {}
}

# ----------------------------------------------------------------------------------------------------------------------
# EKS 노드 그룹 설정
# ----------------------------------------------------------------------------------------------------------------------
variable "cluster_name" {
  description = "EKS 클러스터 이름"
  type        = string
}

variable "node_role_arn" {
  description = "EKS 노드 그룹에서 사용할 IAM Role ARN"
  type        = string
}

variable "subnet_ids" {
  description = "노드 그룹이 배치될 서브넷 ID 목록"
  type        = list(string)
}

variable "capacity_type" {
  description = "ON_DEMAND 또는 SPOT"
  type        = string
  default     = "ON_DEMAND"
}

variable "ami_type" {
  description = "EKS 노드 그룹에 사용할 AMI 타입"
  type        = string
  default     = "AL2_x86_64"
}

variable "instance_types" {
  description = "노드 그룹에 사용할 EC2 인스턴스 타입"
  type    = list(string)
}

variable "desired_size" {
  description = "노드 그룹의 원하는 노드 수"
  type    = number
}

variable "min_size" {
  description = "노드 그룹의 최소 노드 수"
  type    = number
}

variable "max_size" {
  description = "노드 그룹의 최대 노드 수"
  type    = number
}

variable "max_unavailable" {
  description = "업데이트 시 동시에 비활성화할 수 있는 노드 수"
  type        = number
  default     = null
}

variable "ec2_ssh_key" {
  description = "EKS 노드 SSH용 키페어 이름"
  type        = string
}

variable "remote_access_sg_ids" {
  description = "SSH 접근을 허용할 보안 그룹 ID 리스트"
  type        = list(string)
}

variable "labels" {
  description = "Kubernetes 노드 라벨"
  type        = map(string)
  default     = {}
}

variable "enable_autoscaler_tags" {
  description = "Cluster Autoscaler 태그 활성화 여부"
  type        = bool
  default     = false
}