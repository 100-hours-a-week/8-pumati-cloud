# providers.tf - 프로바이더 및 공통 상태 참조 설정

# 공통 인프라 상태를 원격에서 참조
# (00-common에서 project_id, region, environment, common_tags 등 출력 필요)
data "terraform_remote_state" "common" {
  backend = "s3"
  config = {
    bucket = "s3-terraform-ktb8team"
    key    = "gcp/dev/common/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# 공통 출력값을 local 변수로 할당
locals {
  project_id   = data.terraform_remote_state.common.outputs.project_id
  region       = data.terraform_remote_state.common.outputs.region
  environment  = data.terraform_remote_state.common.outputs.environment
  common_tags  = data.terraform_remote_state.common.outputs.common_tags
}

locals {
  # startup-script.sh를 템플릿으로 읽고 변수를 치환
  startup_script_content = templatefile(
    "${path.module}/startup-script.sh", 
    {
      TUNNEL_UUID = var.cloudflare_tunnel_uuid,
      WEBHOOK_URL = var.discord_webhook_url
    }
  )
}

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# GCP Provider 설정
provider "google" {
  project     = local.project_id
  region      = local.region
  credentials = file("${path.module}/../../terraform-key.json")
}
