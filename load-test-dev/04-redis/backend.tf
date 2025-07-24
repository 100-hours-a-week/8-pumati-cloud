terraform {
  backend "s3" {
    bucket = "8-ktb-chat-tfstate"
    key    = "terraform/load-test/redis/terraform.tfstate"
    region = "ap-northeast-2"
  }
} 