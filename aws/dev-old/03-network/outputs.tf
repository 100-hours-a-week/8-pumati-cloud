output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

# 하위 호환성을 위한, 이전 이름의 서브넷 출력
output "subnet_id" {
  description = "기본 서브넷 ID (하위 호환성용)"
  value       = aws_subnet.public_subnet_a.id
}

# 새로운 출력
output "public_subnet_a_id" {
  description = "퍼블릭 서브넷 A의 ID"
  value       = aws_subnet.public_subnet_a.id
}

output "public_subnet_c_id" {
  description = "퍼블릭 서브넷 C의 ID"
  value       = aws_subnet.public_subnet_c.id
}

# ALB에서 사용할 모든 서브넷 ID 목록
output "public_subnet_ids" {
  description = "모든 퍼블릭 서브넷 ID 목록"
  value       = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_c.id]
}

output "igw_id" {
  description = "인터넷 게이트웨이 ID"
  value       = aws_internet_gateway.igw.id
}

output "route_table_id" {
  description = "퍼블릭 라우팅 테이블 ID"
  value       = aws_route_table.public_rt.id
}
