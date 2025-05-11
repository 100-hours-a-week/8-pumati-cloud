terraform {
  backend "s3" {
    bucket       = "s3-terraform-ktb8team"
    key          = "gcp/cicd/common/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}