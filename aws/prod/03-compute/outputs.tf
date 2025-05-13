# ------------------------------------------------------------
# 프론트엔드 인스턴스 출력값
# ------------------------------------------------------------
output "frontend_instance_id" {
  description = "프론트엔드 인스턴스 ID"
  value       = module.frontend.frontend_instance_id
}

output "frontend_public_ip" {
  description = "프론트엔드 인스턴스 퍼블릭 IP"
  value       = module.frontend.frontend_public_ip
}

output "frontend_private_ip" {
  description = "프론트엔드 인스턴스 프라이빗 IP"
  value       = module.frontend.frontend_private_ip
}

# ------------------------------------------------------------
# 백엔드 인스턴스 출력값
# ------------------------------------------------------------
output "backend_instance_id" {
  description = "백엔드 인스턴스 ID"
  value       = module.backend.backend_instance_id
}

output "backend_public_ip" {
  description = "백엔드 인스턴스 퍼블릭 IP"
  value       = module.backend.backend_public_ip
}

output "backend_private_ip" {
  description = "백엔드 인스턴스 프라이빗 IP"
  value       = module.backend.backend_private_ip
}
