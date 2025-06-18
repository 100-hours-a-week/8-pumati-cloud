# 프론트엔드 인스턴스 출력
output "frontend_instance_id" {
  description = "프론트엔드 인스턴스 ID"
  value       = module.frontend_instance_test.instance_id
}

output "frontend_public_ip" {
  description = "프론트엔드 인스턴스의 퍼블릭 IP (EIP가 연결된 경우)"
  value       = module.frontend_instance_test.public_ip
}

# 백엔드 인스턴스 출력
output "backend_instance_id" {
  description = "백엔드 인스턴스 ID"
  value       = module.backend_instance_test.instance_id
}

output "backend_public_ip" {
  description = "백엔드 인스턴스의 퍼블릭 IP"
  value       = module.backend_instance_test.public_ip
}