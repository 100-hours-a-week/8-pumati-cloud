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
# EKS 클러스터 설정
# ----------------------------------------------------------------------------------------------------------------------
variable "kubernetes_version" {
  description = "EKS Kubernetes 버전"
  type        = string
}

variable "support_type" {
  description = "EKS 클러스터 지원 정책 (STANDARD 또는 EXTENDED)"
  type        = string
  default     = "STANDARD"
  
  validation {
    condition     = contains(["STANDARD", "EXTENDED"], var.support_type)
    error_message = "support_type은 STANDARD 또는 EXTENDED 중 하나여야 합니다."
  }
}

variable "cluster_role_arn" {
  description = "EKS 클러스터 IAM Role ARN"
  type        = string
}

variable "subnet_ids" {
  description = "클러스터가 사용할 서브넷 리스트"
  type        = list(string)
}

variable "cluster_security_group_id" {
  description = "EKS 클러스터에 적용할 보안 그룹 ID"
  type        = string
}

variable "endpoint_private_access" {
  description = "프라이빗 API 접근 허용 여부"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "퍼블릭 API 접근 허용 여부"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "퍼블릭 API 접근을 허용할 CIDR 리스트"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}