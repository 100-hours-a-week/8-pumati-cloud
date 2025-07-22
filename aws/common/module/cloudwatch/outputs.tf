output "log_group_name" {
  description = "CloudWatch 로그 그룹 이름"
  value       = aws_cloudwatch_log_group.this.name
}

output "log_group_arn" {
  description = "CloudWatch 로그 그룹 ARN"
  value       = aws_cloudwatch_log_group.this.arn
}

output "log_group_retention_in_days" {
  description = "로그 보존 기간 (일)"
  value       = aws_cloudwatch_log_group.this.retention_in_days
}

output "log_group_kms_key_id" {
  description = "로그 암호화에 사용된 KMS 키 ID"
  value       = aws_cloudwatch_log_group.this.kms_key_id
}
