output "mysql_instance_id" {
  value = aws_instance.mysql.id
}

output "mysql_private_ip" {
  value = aws_instance.mysql.private_ip
}

output "mysql_security_group_id" {
  value = aws_security_group.mysql_sg.id
}

output "db_instance_role_arn" {
  value = aws_iam_role.db_instance_role.arn
  description = "ARN of the IAM role used by the MySQL instance"
}

output "db_instance_profile_name" {
  value = aws_iam_instance_profile.db_instance_profile.name
  description = "Name of the instance profile for the MySQL instance"
}