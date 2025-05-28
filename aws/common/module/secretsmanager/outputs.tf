output "secret_name" {
  description = ".env이 저장된 Secrets Manager의 이름"
  value       = aws_secretsmanager_secret.this.name
}
