# ------------------------------------------------------------
# 프론트엔드 인스턴스 출력값
# ------------------------------------------------------------
output "frontend_instance_id" {
  description = "프론트엔드 인스턴스 ID"
  value       = aws_instance.frontend.id
}

output "frontend_public_ip" {
  description = "프론트엔드 인스턴스 퍼블릭 IP"
  value       = aws_instance.frontend.public_ip
}

output "frontend_private_ip" {
  description = "프론트엔드 인스턴스 프라이빗 IP"
  value       = aws_instance.frontend.private_ip
}

# ------------------------------------------------------------
# 백엔드 인스턴스 출력값
# ------------------------------------------------------------
output "backend_instance_id" {
  description = "백엔드 인스턴스 ID"
  value       = aws_instance.backend.id
}

output "backend_public_ip" {
  description = "백엔드 인스턴스 퍼블릭 IP"
  value       = aws_instance.backend.public_ip
}

output "backend_private_ip" {
  description = "백엔드 인스턴스 프라이빗 IP"
  value       = aws_instance.backend.private_ip
}

# ------------------------------------------------------------
# DB 인스턴스 출력값
# ------------------------------------------------------------
# output "db_instance_id" {
#   description = "DB 인스턴스 ID"
#   value       = aws_instance.db.id
# }

# output "db_public_ip" {
#   description = "DB 인스턴스 퍼블릭 IP"
#   value       = aws_instance.db.public_ip
# }

# output "db_private_ip" {
#   description = "DB 인스턴스 프라이빗 IP"
#   value       = aws_instance.db.private_ip
# }
