resource "aws_secretsmanager_secret" "this" {
  name        = "${var.project_name}-${var.environment}-${var.service_name}-.env"
  description = "${var.service_name} .env for ${var.environment} 환경"
  kms_key_id  = var.kms_key_id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-${var.service_name}-.env"
  })
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id     = aws_secretsmanager_secret.this.id
  secret_string = file("${var.env_file_path}")
}
