# load-test-dev/02-mongoDB/outputs.tf
# MongoDB 단일 인스턴스 출력 변수

# MongoDB 인스턴스 정보
output "mongodb_instance_id" {
  description = "MongoDB 인스턴스 ID"
  value       = aws_instance.mongodb.id
}

output "mongodb_private_ip" {
  description = "MongoDB 인스턴스 프라이빗 IP"
  value       = aws_instance.mongodb.private_ip
}

output "mongodb_public_ip" {
  description = "MongoDB 인스턴스 퍼블릭 IP (Elastic IP)"
  value       = aws_eip.mongodb.public_ip
}

output "mongodb_private_dns" {
  description = "MongoDB 인스턴스 프라이빗 DNS"
  value       = aws_instance.mongodb.private_dns
}

output "mongodb_public_dns" {
  description = "MongoDB 인스턴스 퍼블릭 DNS"
  value       = aws_instance.mongodb.public_dns
}

# MongoDB 연결 정보
output "mongodb_connection_string" {
  description = "MongoDB 연결 문자열 (프라이빗 IP 사용)"
  value       = "mongodb://${aws_instance.mongodb.private_ip}:27017/loadtest"
}

output "mongodb_external_connection_string" {
  description = "MongoDB 연결 문자열 (퍼블릭 IP 사용)"
  value       = "mongodb://${aws_eip.mongodb.public_ip}:27017/loadtest"
}

output "mongodb_port" {
  description = "MongoDB 포트"
  value       = 27017
}

output "mongodb_database" {
  description = "기본 데이터베이스 이름"
  value       = "loadtest"
}

# 보안 그룹 정보
output "mongodb_security_group_id" {
  description = "MongoDB 보안 그룹 ID"
  value       = aws_security_group.mongodb.id
}

# 서브넷 정보
output "mongodb_subnet_id" {
  description = "MongoDB 인스턴스가 배치된 서브넷 ID"
  value       = aws_instance.mongodb.subnet_id
}

output "mongodb_availability_zone" {
  description = "MongoDB 인스턴스 가용 영역"
  value       = aws_instance.mongodb.availability_zone
} 