terraform {
  backend "s3" {
    bucket       = "s3-pumati-tfstate"
    key          = "terraform/shared/network/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}
