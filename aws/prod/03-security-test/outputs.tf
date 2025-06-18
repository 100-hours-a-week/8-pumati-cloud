# sg
output "alb_sg_id" {
  value       = module.alb_sg.security_group_id
  description = "ALB 보안 그룹 ID"
}

output "frontend_sg_id" {
  value       = module.frontend_sg.security_group_id
  description = "프론트엔드 인스턴스 보안 그룹 ID"
}

output "backend_sg_id" {
  value       = module.backend_sg.security_group_id
  description = "백엔드 인스턴스 보안 그룹 ID"
}

output "management_sg_id" {
  value       = module.management_sg.security_group_id
  description = "Management 인스턴스 보안 그룹 ID"
}

# iam
output "frontend_instance_profile_name" {
  value       = module.frontend_iam.instance_profile_name
  description = "프론트엔드 인스턴스에 연결할 IAM Instance Profile"
}

output "backend_instance_profile_name" {
  description = "백엔드 인스턴스 IAM 프로파일 이름"
  value       = module.backend_iam.instance_profile_name
}

output "management_instance_profile_name" {
  description = "Management 인스턴스 IAM 프로파일 이름"
  value       = module.management_iam.instance_profile_name
}
