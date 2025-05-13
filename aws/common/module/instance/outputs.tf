# ------------------------------------------------------------
# 프론트엔드 인스턴스 출력
# ------------------------------------------------------------
output "frontend_instance_id" {
  description = "프론트엔드 인스턴스 ID"
  value       = try(aws_instance.frontend[0].id, null)
}

output "frontend_private_ip" {
  description = "프론트엔드 인스턴스 프라이빗 IP"
  value       = try(aws_instance.frontend[0].private_ip, null)
}

output "frontend_public_ip" {
  description = "프론트엔드 인스턴스 퍼블릭 IP"
  value       = try(aws_instance.frontend[0].public_ip, null)
}


# ------------------------------------------------------------
# 백엔드 인스턴스 출력
# ------------------------------------------------------------
output "backend_instance_id" {
  description = "백엔드 인스턴스 ID"
  value       = try(aws_instance.backend[0].id, null)
}

output "backend_private_ip" {
  description = "백엔드 인스턴스 프라이빗 IP"
  value       = try(aws_instance.backend[0].private_ip, null)
}

output "backend_public_ip" {
  description = "백엔드 인스턴스 퍼블릭 IP"
  value       = try(aws_instance.backend[0].public_ip, null)
}

# # ------------------------------------------------------------
# # DB 인스턴스 출력
# # ------------------------------------------------------------
# output "db_instance_id" {
#   description = "DB 인스턴스 ID"
#   value       = try(aws_instance.db[0].id, null)
# }

# output "db_private_ip" {
#   description = "DB 인스턴스 프라이빗 IP"
#   value       = try(aws_instance.db[0].private_ip, null)
# }

# output "db_public_ip" {
#   description = "DB 인스턴스 퍼블릭 IP"
#   value       = try(aws_instance.db[0].public_ip, null)
# }