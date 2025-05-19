output "mig_off_scheduler_name" {
  description = "MIG 크기를 0으로 조정하는 스케줄러 이름"
  value       = google_cloud_scheduler_job.resize_mig_off.name
}

output "mig_on_scheduler_name" {
  description = "MIG 크기를 1로 조정하는 스케줄러 이름"
  value       = google_cloud_scheduler_job.resize_mig_on.name
}

