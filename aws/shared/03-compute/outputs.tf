# OpenVPN 인스턴스 출력
output "openvpn_instance_id" {
  description = "OpenVPN 인스턴스 ID"
  value       = module.openvpn_instance.instance_id
}

output "openvpn_public_ip" {
  description = "OpenVPN 인스턴스의 퍼블릭 IP"
  value       = module.openvpn_instance.public_ip
}