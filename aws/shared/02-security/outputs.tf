output "openvpn_sg_id" {
  value       = module.openvpn_sg.security_group_id
  description = "OpenVPN 인스턴스 보안 그룹 ID"
}

output "management_sg_id" {
  value       = module.management_sg.security_group_id
  description = "Management 인스턴스 보안 그룹 ID"
}

output "management_instance_profile_name" {
  description = "Management 인스턴스 IAM 프로파일 이름"
  value       = module.management_iam.instance_profile_name
}