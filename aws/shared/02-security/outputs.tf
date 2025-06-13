output "openvpn_sg_id" {
  value       = module.openvpn_sg.security_group_id
  description = "OpenVPN 인스턴스 보안 그룹 ID"
}