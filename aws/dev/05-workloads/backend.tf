terraform {
  backend "s3" {
    bucket       = "pumati-s3-jacky"
    key          = "terraform/dev/workloads/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}