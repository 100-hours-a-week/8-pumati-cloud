# load-test/02-mongoDB/backend.tf
# Terraform 백엔드 설정

terraform {
  backend "s3" {
    bucket = "8-ktb-chat-tfstate"
    key    = "terraform/load-test/mongodb/terraform.tfstate"
    region = "ap-northeast-2"
  }
} 