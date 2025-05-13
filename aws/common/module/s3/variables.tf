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
# S3 버킷 변수
# ------------------------------------------------------------
variable "bucket_name" {
  description = "S3 버킷 이름"
  type        = string
  # 버킷 이름 유효성 검사: 소문자, 숫자, 점(.), 하이픈(-)만 사용 가능, 3-63자
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.bucket_name))
    error_message = "버킷 이름은 소문자, 숫자, 점(.), 하이픈(-)만 사용 가능하며, 3-63자 사이여야 합니다."
  }
}

variable "force_destroy" {
  description = "S3 버킷을 강제로 삭제할지 여부 (true면 삭제 가능)"
  type        = bool
  default     = true
}

# ------------------------------------------------------------
# 버전 관리 변수
# ------------------------------------------------------------
variable "enable_versioning" {
  description = "S3 버킷의 버전 관리 활성화 여부"
  type        = bool
  default     = true
}

# ------------------------------------------------------------
# 수명 주기 규칙 변수
# ------------------------------------------------------------
variable "enable_lifecycle_rule" {
  description = "수명 주기 규칙 활성화 여부"
  type        = bool
  default     = true
}

variable "lifecycle_rule_days" {
  description = "수명 주기 규칙 적용 일수 (오래된 버전 자동 삭제)"
  type        = number
  default     = 120
}

# ------------------------------------------------------------
# 암호화 변수
# ------------------------------------------------------------
variable "enable_encryption" {
  description = "서버 사이드 암호화 활성화 여부"
  type        = bool
  default     = true
}

variable "encryption_algorithm" {
  description = "서버 사이드 암호화 알고리즘"
  type        = string
  default     = "AES256"
}

# ------------------------------------------------------------
# 접근 제어 변수
# ------------------------------------------------------------
variable "block_public_access" {
  description = "퍼블릭 액세스 차단 기능 활성화 여부"
  type        = bool
  default     = true
}

variable "block_public_acls" {
  description = "퍼블릭 ACL 차단 여부"
  type        = bool
  default     = true
}

variable "block_public_policy" {
  description = "퍼블릭 정책 차단 여부"
  type        = bool
  default     = false
}

variable "ignore_public_acls" {
  description = "퍼블릭 ACL 무시 여부"
  type        = bool
  default     = true
}

variable "restrict_public_buckets" {
  description = "퍼블릭 버킷 접근 제한 여부"
  type        = bool
  default     = true
}

variable "terraform_state_user_arns" {
  description = "버킷 접근 권한을 부여할 IAM 사용자 ARN 목록"
  type        = list(string)
  default     = []
}

variable "allowed_actions" {
  description = "IAM 사용자에게 허용할 S3 액션 목록"
  type        = list(string)
  default     = [
    "s3:GetBucketPolicy",
    "s3:ListBucket",
    "s3:GetObject",
    "s3:PutObject"
  ]
}

# ------------------------------------------------------------
# 폴더 구조 변수
# ------------------------------------------------------------
variable "create_folders" {
  description = "S3 버킷 내에 폴더를 생성할지 여부"
  type        = bool
  default     = false
}

variable "folders" {
  description = "S3 버킷 내에 생성할 폴더 목록 (예: ['logs/', 'data/raw/', 'data/processed/'])"
  type        = list(string)
  default     = []
} 