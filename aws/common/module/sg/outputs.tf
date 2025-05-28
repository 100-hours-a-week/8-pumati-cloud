output "security_group_id" {
  value       = aws_security_group.this.id
  description = "생성된 보안 그룹 ID"
}
