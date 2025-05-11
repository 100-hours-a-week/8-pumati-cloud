output "scheduler_sa_email" {
  description = "스케줄러 서비스 계정 이메일"
  value       = google_service_account.scheduler_sa.email
}

output "mig_off_scheduler_name" {
  description = "MIG 크기를 0으로 조정하는 스케줄러 이름"
  value       = google_cloud_scheduler_job.resize_mig_off.name
}

output "mig_on_scheduler_name" {
  description = "MIG 크기를 1로 조정하는 스케줄러 이름"
  value       = google_cloud_scheduler_job.resize_mig_on.name
}
