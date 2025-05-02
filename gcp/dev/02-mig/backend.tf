terraform {
  backend "s3" {
    bucket       = "s3-terraform-ktb8team"
    key          = "gcp/dev/mig/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}