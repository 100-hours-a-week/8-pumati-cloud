# modules/vpc/outputs.tf

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR 블록"
  value       = aws_vpc.this.cidr_block
}

output "internet_gateway_id" {
  description = "인터넷 게이트웨이 ID"
  value       = aws_internet_gateway.this.id
}

output "public_subnet_id" {
  description = "퍼블릭 서브넷 ID"
  value       = aws_subnet.public.id
}

output "public_subnet_cidr_block" {
  description = "퍼블릭 서브넷 CIDR 블록"
  value       = aws_subnet.public.cidr_block
}

output "public_route_table_id" {
  description = "퍼블릭 라우팅 테이블 ID"
  value       = aws_route_table.public.id
}

output "service_subnet_id" {
  description = "서비스 서브넷 ID (사용되는 경우)"
  value       = try(aws_subnet.service[0].id, null)
}

output "db_subnet_id" {
  description = "DB 서브넷 ID (사용되는 경우)"
  value       = try(aws_subnet.db[0].id, null)
}