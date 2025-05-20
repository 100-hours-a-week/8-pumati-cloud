terraform {
  backend "s3" {
    bucket       = "s3-terraform-pumati"
    key          = "aws/dev/base/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}
