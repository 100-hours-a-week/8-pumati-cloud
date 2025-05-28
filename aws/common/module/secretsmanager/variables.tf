variable "env" {
  description = "환경 이름 (예: dev, prod)"
  type        = string
}

variable "env_file_path" {
  description = "로컬 .env 파일의 전체 경로"
  type        = string
}

variable "kms_key_id" {
  description = "Secrets Manager에서 사용할 KMS 키의 ARN 또는 ID. 지정하지 않으면 AWS 기본 KMS 키를 사용합니다."
  type        = string
  default     = null
}
