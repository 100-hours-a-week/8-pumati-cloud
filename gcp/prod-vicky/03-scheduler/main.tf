# gcp/dev/03-scheduler/main.tf

# 사용을 위해서는 Cloud Build API, Cloud Scheduler API 활성화 필요.

# 내가 만든건 region MIG(리전안에서 여러 존에 아무데나 생성가능)이 아니라 zone MIG(존 고정)이라서 오류가 나는 것임.
# MIG가 영역(zonal) MIG이지 지역(regional) MIG가 아닙니다. 스크린샷에서 위치가 asia-east1-a로 표시되어 있습니다. 이것은 영역(zone) 단위의 MIG라는 의미입니다.
# 테라폼 코드를 수정하여 --region 대신 --zone 플래그를 사용하세요

#uri 보내는게 클라우드빌드 api 로 보내니까, 잘 안될때는 클라우드빌드 로그 보면 됨!

# 서비스 계정에 필요한 권한 부여
resource "google_project_iam_member" "terraform_cloudbuild_admin" {
  project = local.project_id
  role    = "roles/cloudbuild.builds.editor"
  member  = "serviceAccount:terraform@loyal-parser-463101-n8.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "cloudbuild_compute_admin" {
  project = local.project_id
  role    = "roles/compute.admin"
  member  = "serviceAccount:terraform@loyal-parser-463101-n8.iam.gserviceaccount.com"
}

# 크기를 0으로 조정하는 스케줄러
resource "google_cloud_scheduler_job" "resize_mig_off" {
  name        = "resize-gpu-mig-to-0"
  description = "prod GPU MIG 크기를 0으로 조정"
  schedule    = "0 22 * * *"
  time_zone   = "Asia/Seoul"

  http_target {
    http_method = "POST"
    uri         = "https://cloudbuild.googleapis.com/v1/projects/${local.project_id}/builds"
    oauth_token {
      service_account_email = "terraform@loyal-parser-463101-n8.iam.gserviceaccount.com"
    }
    body = base64encode(jsonencode({
      steps = [
        {
          name       = "gcr.io/cloud-builders/gcloud"
          entrypoint = "bash"
          args       = ["-c", "gcloud compute instance-groups managed resize ${local.mig_name} --size=0 --zone=${local.mig_zone}"]
        },
        {
          name       = "gcr.io/cloud-builders/curl"
          entrypoint = "bash"
          args = [
            "-c", <<-EOT
            curl -H "Content-Type: application/json" \
                 -X POST \
                 -d '{"embeds": [{"title": "🔴 prod GPU 종료", "description": "prod GPU 인스턴스와 AI빌드 자동화 기능이 종료됩니다.", "color": 16711680}]}' \
                 ${local.discord_webhook_url_all}
            EOT
          ]
        }
      ]
    }))
    headers = {
      "Content-Type" = "application/json"
    }
  }
}

# MIG 크기를 1로 조정하는 스케줄러
resource "google_cloud_scheduler_job" "resize_mig_on" {
  name        = "resize-gpu-mig-to-1"
  description = "prod GPU MIG 크기를 1로 조정"
  schedule    = "0 8 * * *"
  time_zone   = "Asia/Seoul"

  http_target {
    http_method = "POST"
    uri         = "https://cloudbuild.googleapis.com/v1/projects/${local.project_id}/builds"
    oauth_token {
      service_account_email = "terraform@loyal-parser-463101-n8.iam.gserviceaccount.com"
    }
    body = base64encode(jsonencode({
      steps = [
        {
          name       = "gcr.io/cloud-builders/gcloud"
          entrypoint = "bash"
          args       = ["-c", "gcloud compute instance-groups managed resize ${local.mig_name} --size=1 --zone=${local.mig_zone}"]
        },
        {
          name       = "gcr.io/cloud-builders/curl"
          entrypoint = "bash"
          args = [
            "-c", <<-EOT
            curl -H "Content-Type: application/json" \
                 -X POST \
                 -d '{"embeds": [{"title": "🟢 prod GPU 시작", "description": "prod GPU 인스턴스와 AI빌드 자동화 기능이 시작됩니다.", "color": 65280}]}' \
                 ${local.discord_webhook_url_all}
            EOT
          ]
        }
      ]
    }))
    headers = {
      "Content-Type" = "application/json"
    }
  }
}
