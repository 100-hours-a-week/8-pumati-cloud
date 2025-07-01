output "instance_profile_name" {
  description = "EC2에 연결할 IAM 인스턴스 프로파일 이름"
  value       = var.instance_profile_enabled ? aws_iam_instance_profile.this[0].name : null
}
