terraform {
  backend "s3" {
    bucket       = "s3-terraform-ktb8team"
    key          = "gcp/prod-vicky/static/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}