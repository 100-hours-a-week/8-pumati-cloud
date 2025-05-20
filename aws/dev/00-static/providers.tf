terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "terraform_remote_state" "common" {
  backend = "s3"

  config = {
    bucket = "s3-terraform-ktb8team"
    key    = "aws/dev/common/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

locals {
  project_name = data.terraform_remote_state.common.outputs.project_name
  domain_name = data.terraform_remote_state.common.outputs.domain_name
  region = data.terraform_remote_state.common.outputs.region
  environment = data.terraform_remote_state.common.outputs.environment
  common_tags  = data.terraform_remote_state.common.outputs.common_tags
}

provider "aws" {
  region = local.region

  default_tags {
    tags = local.common_tags
  }
}
