terraform {
  backend "s3" {
    bucket       = "8-ktb-chat-tfstate"
    key          = "terraform/load-test/network/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}
