# providers.tf - 프로바이더 설정 파일

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Common 모듈의 상태를 참조
data "terraform_remote_state" "common" {
  backend = "s3"
  config = {
    bucket = "s3-terraform-ktb8team"
    key    = "gcp/cicd/common/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Common 모듈의 출력 값 사용
locals {
  project_id  = data.terraform_remote_state.common.outputs.project_id
  region      = data.terraform_remote_state.common.outputs.region
  environment = data.terraform_remote_state.common.outputs.environment
  zone        = data.terraform_remote_state.common.outputs.zone

  common_tags = data.terraform_remote_state.common.outputs.common_tags
  common_labels = data.terraform_remote_state.common.outputs.common_labels
}

data "terraform_remote_state" "static" {
  backend = "s3"
  config = {
    bucket = "s3-terraform-ktb8team"
    key    = "gcp/cicd/static/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

locals {
  jenkins_master_disk_self_link = data.terraform_remote_state.static.outputs.jenkins_master_disk_self_link
}

# 프로바이더 설정
provider "google" {
  project     = local.project_id
  region      = local.region
  credentials = file("${path.module}/../../common/terraform-keys/terraform-key-cicd.json")
}
