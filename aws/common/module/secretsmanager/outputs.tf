output "secret_arn" {
  description = "Secrets Manager 리소스 ARN"
  value       = aws_secretsmanager_secret.this.arn
}

output "secret_name" {
  description = "Secrets Manager 이름"
  value       = aws_secretsmanager_secret.this.name
}
