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

# ------------------------------------------------------------
# Jenkins 인스턴스 출력
# ------------------------------------------------------------
output "jenkins_instance_id" {
  description = "Jenkins 인스턴스 ID"
  value       = try(aws_instance.jenkins[0].id, null)
}

output "jenkins_private_ip" {
  description = "Jenkins 인스턴스 프라이빗 IP"
  value       = try(aws_instance.jenkins[0].private_ip, null)
}

output "jenkins_public_ip" {
  description = "Jenkins 인스턴스 퍼블릭 IP"
  value       = try(aws_instance.jenkins[0].public_ip, null)
}
