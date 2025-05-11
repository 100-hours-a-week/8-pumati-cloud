# providers.tf - 프로바이더 및 공통 상태 참조 설정

# 커스텀 이미지 존재 여부를 테라폼 함수로 안전하게 처리
locals {

  # 기본 이미지 경로
  default_image = "projects/deeplearning-platform-release/global/images/family/pytorch-latest-cu121-ubuntu-2204-py310"
  
  # 커스텀 이미지 경로 (이미지가 존재한다면 사용)
  pumati_image = "projects/${local.project_id}/global/images/family/pumati-ai"
  
}

# locals 추가
locals {
  # 이미지 경로 생성
  custom_image_path = "projects/${local.project_id}/global/images/${var.custom_image_name}"
  
  # 스타트업 스크립트 - 커스텀 이미지가 아닐 때만 사용 (이름 변경)
  final_startup_script = var.use_custom_image ? "" : local.startup_script_content
}

# 공통 인프라 상태를 원격에서 참조
# (00-common에서 project_id, region, environment, common_tags 등 출력 필요)
data "terraform_remote_state" "common" {
  backend = "s3"
  config = {
    bucket = "s3-terraform-ktb8team"
    key    = "gcp/prod/common/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# 공통 출력값을 local 변수로 할당
locals {
  project_id  = data.terraform_remote_state.common.outputs.project_id
  region      = data.terraform_remote_state.common.outputs.region
  environment = data.terraform_remote_state.common.outputs.environment
  zone       = data.terraform_remote_state.common.outputs.zone
  # 공통 태그와 라벨 가져오기
  common_tags = data.terraform_remote_state.common.outputs.common_tags
  common_labels = data.terraform_remote_state.common.outputs.common_labels
}

# 01-static 상태를 원격에서 참조
# (01-static에서 생성한 시크릿 정보를 가져옴)
data "terraform_remote_state" "static" {
  backend = "s3"
  config = {
    bucket = "s3-terraform-ktb8team"
    key    = "gcp/prod/static/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# 시크릿 데이터 가져오기
data "google_secret_manager_secret_version" "discord" {
  project = local.project_id
  secret  = data.terraform_remote_state.static.outputs.discord_webhook_secret_id
  version = "latest"
}

data "google_secret_manager_secret_version" "cloudflare" {
  project = local.project_id
  secret  = data.terraform_remote_state.static.outputs.cloudflare_tunnel_secret_id
  version = "latest"
}

data "google_secret_manager_secret_version" "github" {
  project = local.project_id
  secret  = data.terraform_remote_state.static.outputs.github_token_secret_id
  version = "latest"
}

data "google_secret_manager_secret_version" "sa_key" {
  project = local.project_id
  secret  = data.terraform_remote_state.static.outputs.sa_key_secret_id
  version = "latest"
}

data "google_secret_manager_secret_version" "discord_ai" {
  project = local.project_id
  secret  = data.terraform_remote_state.static.outputs.discord_webhook_secret_ai_id
  version = "latest"
}

locals {
  # 시크릿 값을 가져오기
  discord_webhook = data.google_secret_manager_secret_version.discord.secret_data
  cloudflare_tunnel = data.google_secret_manager_secret_version.cloudflare.secret_data
  github_token = data.google_secret_manager_secret_version.github.secret_data
  sa_key = data.google_secret_manager_secret_version.sa_key.secret_data
  discord_webhook_ai = data.google_secret_manager_secret_version.discord_ai.secret_data
  
  # SA_KEY를 Base64로 인코딩
  sa_key_base64 = base64encode(local.sa_key)
  
  # 스크립트에 값 전달
  startup_script_content = templatefile(
    "${path.module}/startup-script.sh",
    {
      TUNNEL_UUID        = local.cloudflare_tunnel
      WEBHOOK_URL        = local.discord_webhook
      GITHUB_TOKEN       = local.github_token
      WEBHOOK_URL_AI      = local.discord_webhook_ai
      # SA_KEY 대신 Base64 인코딩된 값을 전달
      SA_KEY_CONTENT_BASE64 = local.sa_key_base64 
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

# 프로바이더 설정
provider "google" {
  project     = local.project_id
  region      = local.region
  credentials = file("${path.module}/../../common/terraform-keys/terraform-key-prod.json")
}
