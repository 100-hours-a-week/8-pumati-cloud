output "instance_id" {
  description = "생성된 인스턴스 ID"
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "실제 접근 가능한 퍼블릭 IP 주소 (EIP 있으면 EIP 주소, 없으면 인스턴스 퍼블릭 IP 주소 출력)"
  value       = try(aws_eip.this[0].public_ip, aws_instance.this.public_ip)
}

output "private_ip" {
  description = "프라이빗 IP 주소"
  value       = aws_instance.this.private_ip
}
