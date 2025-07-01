# 1. Terraform State 저장용 S3
module "terraform_state" {
  source = "../../common/module/s3"
  
  # 기본 설정
  bucket_name = "s3-pumati-tfstate"
  environment = "prod"
  project_name = "terraform"
  
  # 버전 관리 설정
  enable_versioning = true
  
  # 수명 주기 규칙 설정
  enable_lifecycle_rule = true
  lifecycle_rule_days = 120
  
  # 암호화 설정
  enable_encryption = true
  encryption_algorithm = "AES256"
  
  # 보안 설정
  block_public_access = true
  block_public_acls = true
  block_public_policy = false
  ignore_public_acls = true
  restrict_public_buckets = true
  
  # 접근 정책
  terraform_state_user_arns = [
    "arn:aws:iam::236450698266:user/rowan"
  ]
  allowed_actions = [
    "s3:GetBucketPolicy",
    "s3:ListBucket",
    "s3:GetObject",
    "s3:PutObject"
  ]
  
  # 태그
  tags = {
    Purpose = "Terraform State Storage"
    ManagedBy = "Terraform"
  }
}

# 2. 모니터링 로그 수집용 S3
module "monitoring_logs" {
  source = "../../common/module/s3"
  
  # 기본 설정
  bucket_name = "s3-pumati-monitoring-logs"
  environment = "shared"
  project_name = "monitoring"
  
  # 버전 관리 설정
  enable_versioning = true
  
  # 수명 주기 규칙 설정
  enable_lifecycle_rule = true
  lifecycle_rule_days = 90  # 로그는 더 짧게 보관
  
  # 암호화 설정
  enable_encryption = true
  encryption_algorithm = "AES256"
  
  # 보안 설정
  block_public_access = true
  block_public_acls = true
  block_public_policy = false
  ignore_public_acls = true
  restrict_public_buckets = true
  
  # 접근 정책
  terraform_state_user_arns = [
    "arn:aws:iam::236450698266:user/rowan"
  ]
  allowed_actions = [
    "s3:GetBucketPolicy",
    "s3:ListBucket",
    "s3:GetObject",
    "s3:PutObject"
  ]
  
  # 태그
  tags = {
    Purpose = "Monitoring Logs Storage"
    ManagedBy = "Terraform"
  }
}

# 3. 공용 S3
module "common_storage" {
  source = "../../common/module/s3"
  
  # 기본 설정
  bucket_name = "s3-pumati-common-storage"
  environment = "prod"
  project_name = "common"
  
  # 버전 관리 설정
  enable_versioning = true
  
  # 수명 주기 규칙 설정
  enable_lifecycle_rule = true
  lifecycle_rule_days = 180  # 공용 데이터는 더 오래 보관
  
  # 암호화 설정
  enable_encryption = true
  encryption_algorithm = "AES256"
  
  # 보안 설정
  block_public_access = true
  block_public_acls = true
  block_public_policy = false
  ignore_public_acls = true
  restrict_public_buckets = true
  
  # 접근 정책
  terraform_state_user_arns = [
    "arn:aws:iam::236450698266:user/rowan"
  ]
  allowed_actions = [
    "s3:GetBucketPolicy",
    "s3:ListBucket",
    "s3:GetObject",
    "s3:PutObject"
  ]
  
  # 태그
  tags = {
    Purpose = "Common Storage"
    ManagedBy = "Terraform"
  }
}