output "mig_name" {
  description = "관리형 인스턴스 그룹 이름"
  value       = module.l4_mig.mig_name
}

output "mig_region" {
  description = "관리형 인스턴스 그룹 리전"
  value       = module.l4_mig.region
}

output "mig_zone" {
  description = "관리형 인스턴스 그룹 존"
  value       = module.l4_mig.zone
}