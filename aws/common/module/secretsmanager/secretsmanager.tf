resource "aws_secretsmanager_secret" "this" {
  name        = "${var.env}/frontend/.env"
  description = "Frontend .env for ${var.env} 환경"
  kms_key_id  = var.kms_key_id
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id     = aws_secretsmanager_secret.this.id
  secret_string = file("${var.env_file_path}")
}
