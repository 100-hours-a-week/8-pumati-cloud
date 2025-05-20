output "mysql_instance_id" {
  value = aws_instance.mysql.id
}

output "mysql_private_ip" {
  value = aws_instance.mysql.private_ip
}

output "mysql_public_ip" {
  value = aws_eip.mysql.public_ip
}

output "mysql_security_group_id" {
  value = aws_security_group.mysql_sg.id
}