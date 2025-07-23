# 모든 모듈에서 공통으로 사용될 백엔드 설정
terraform {
  backend "s3" {
    bucket       = "8-ktb-chat-tfstate"
    key          = "aws/prod/common/terraform.tfstate"
    region       = "ap-northeast-2"
    profile      = "ktb-chat"
    encrypt      = true
    use_lockfile = true
  }
}
