# 모든 모듈에서 공통으로 사용될 백엔드 설정
terraform {
  backend "s3" {
    bucket       = "s3-terraform-pumati-v2"
    key          = "aws/prod/dns/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}
