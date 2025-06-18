# 모든 모듈에서 공통으로 사용될 백엔드 설정
terraform {
  backend "s3" {
    bucket       = "s3-pumati-tfstate"
    key          = "aws/prod/security-test/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}
