# 프론트엔드 인스턴스 출력
output "frontend_instance_id" {
  description = "프론트엔드 인스턴스 ID"
  value       = module.frontend_instance.instance_id
}

output "frontend_public_ip" {
  description = "프론트엔드 인스턴스의 퍼블릭 IP (EIP가 연결된 경우)"
  value       = module.frontend_instance.public_ip
}

# 백엔드 인스턴스 출력
output "backend_instance_id" {
  description = "백엔드 인스턴스 ID"
  value       = module.backend_instance.instance_id
}

output "backend_public_ip" {
  description = "백엔드 인스턴스의 퍼블릭 IP"
  value       = module.backend_instance.public_ip
}

# 젠킨스 인스턴스 출력
output "management_instance_id" {
  description = "Management 인스턴스 ID"
  value       = module.management_instance.instance_id
}

output "management_public_ip" {
  description = "Management 인스턴스의 퍼블릭 IP"
  value       = module.management_instance.public_ip
}

# OpenVPN 인스턴스 출력
output "openvpn_instance_id" {
  description = "OpenVPN 인스턴스 ID"
  value       = module.openvpn_instance.instance_id
}

output "openvpn_public_ip" {
  description = "OpenVPN 인스턴스의 퍼블릭 IP"
  value       = module.openvpn_instance.public_ip
}