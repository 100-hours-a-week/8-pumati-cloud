# MySQL 인스턴스 출력
output "mysql_instance_id" {
  description = "MySQL EC2 인스턴스 ID"
  value       = aws_instance.mysql.id
}

output "mysql_private_ip" {
  description = "MySQL 인스턴스 프라이빗 IP"
  value       = aws_instance.mysql.private_ip
}

output "mysql_instance_arn" {
  description = "MySQL 인스턴스 ARN"
  value       = aws_instance.mysql.arn
}

# 보안 그룹 출력
output "mysql_security_group_id" {
  description = "MySQL 보안 그룹 ID"
  value       = aws_security_group.mysql_sg.id
}

# IAM 관련 출력
output "db_instance_role_arn" {
  description = "DB 인스턴스 IAM 역할 ARN"
  value       = aws_iam_role.db_instance_role.arn
}

output "db_instance_profile_name" {
  description = "DB 인스턴스 프로필 이름"
  value       = aws_iam_instance_profile.db_instance_profile.name
}

output "mysql_endpoint" {
  description = "MySQL 엔드포인트 (EKS에서 사용)"
  value       = "${aws_instance.mysql.private_ip}:3306"
}

# CloudWatch 로그 그룹
output "cloudwatch_log_group_name" {
  description = "CloudWatch 로그 그룹 이름"
  value       = aws_cloudwatch_log_group.mysql_logs.name
}

# S3 백업 버킷 정보
output "backup_s3_bucket" {
  description = "백업용 S3 버킷 이름"
  value       = local.s3_bucket_name
}
