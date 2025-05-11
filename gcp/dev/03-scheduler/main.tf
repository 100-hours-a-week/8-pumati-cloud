# gcp/dev/03-scheduler/main.tf


# 정오 12시에 MIG 크기를 0으로 조정하는 스케줄러
resource "google_cloud_scheduler_job" "resize_mig_off" {
  name        = "resize-gpu-mig-to-0"
  description = "오후 12시에 GPU MIG 크기를 0으로 조정"
  schedule    = "0 12 * * *"
  time_zone   = "Asia/Seoul"
  
  http_target {
    http_method = "POST"
    uri         = "https://cloudbuild.googleapis.com/v1/projects/${local.project_id}/builds"
    oauth_token {
      service_account_email = "terraform@ambient-topic-459110-e6.iam.gserviceaccount.com"
    }
    body = base64encode(jsonencode({
      steps = [
        {
          name       = "gcr.io/cloud-builders/gcloud"
          entrypoint = "bash"
          args       = ["-c", "gcloud compute instance-groups managed resize ${local.mig_name} --size=0 --region=${local.mig_region}"]
        }
      ]
    }))
    headers = {
      "Content-Type" = "application/json"
    }
  }
}

# 오전 8시에 MIG 크기를 1로 조정하는 스케줄러
resource "google_cloud_scheduler_job" "resize_mig_on" {
  name        = "resize-gpu-mig-to-1"
  description = "오전 8시에 GPU MIG 크기를 1로 조정"
  schedule    = "0 8 * * *"
  time_zone   = "Asia/Seoul"
  
  http_target {
    http_method = "POST"
    uri         = "https://cloudbuild.googleapis.com/v1/projects/${local.project_id}/builds"
    oauth_token {
      service_account_email = "terraform@ambient-topic-459110-e6.iam.gserviceaccount.com"
    }
    body = base64encode(jsonencode({
      steps = [
        {
          name       = "gcr.io/cloud-builders/gcloud"
          entrypoint = "bash"
          args       = ["-c", "gcloud compute instance-groups managed resize ${local.mig_name} --size=1 --region=${local.mig_region}"]
        }
      ]
    }))
    headers = {
      "Content-Type" = "application/json"
    }
  }
}
