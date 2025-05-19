# ------------------------------------------------------------
# 인스턴스 출력
# ------------------------------------------------------------
output "instance_id" {
  description = "인스턴스 ID"
  value       = aws_instance.instance.id
}

output "private_ip" {
  description = "인스턴스 프라이빗 IP"
  value       = aws_instance.instance.private_ip
}

output "public_ip" {
  description = "인스턴스 퍼블릭 IP"
  value       = aws_instance.instance.public_ip
} 