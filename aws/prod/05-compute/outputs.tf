# 프론트엔드 인스턴스 출력
output "frontend_instance_id" {
  description = "프론트엔드 인스턴스 ID"
  value       = module.frontend_instance.instance_id
}

output "frontend_private_ip" {
  description = "프론트엔드 인스턴스의 프라이빗 IP"
  value       = module.frontend_instance.private_ip
}

# 백엔드 인스턴스 출력
output "backend_instance_id" {
  description = "백엔드 인스턴스 ID"
  value       = module.backend_instance.instance_id
}

output "backend_private_ip" {
  description = "백엔드 인스턴스의 프라이빗 IP"
  value       = module.backend_instance.private_ip
}

# DB 인스턴스 출력
# output "db_instance_id" {
#   description = "DB 인스턴스 ID"
#   value       = module.db_instance.instance_id
# }

# output "db_private_ip" {
#   description = "DB 인스턴스의 프라이빗 IP"
#   value       = module.db_instance.private_ip
# }
