# VPC 출력
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR 블록"
  value       = aws_vpc.main.cidr_block
}

# 인터넷 게이트웨이 출력
output "internet_gateway_id" {
  description = "인터넷 게이트웨이 ID"
  value       = aws_internet_gateway.main.id
}

# 서브넷 출력
output "public_subnet_ids" {
  description = "퍼블릭 서브넷 ID 목록"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "프라이빗 서브넷 ID 목록"
  value       = aws_subnet.private[*].id
}

output "db_subnet_ids" {
  description = "DB 서브넷 ID 목록"
  value       = aws_subnet.db[*].id
}

# 가용 영역 출력
output "availability_zones" {
  description = "사용된 가용 영역"
  value       = data.aws_availability_zones.available.names
}

# NAT 게이트웨이 출력
output "nat_gateway_ids" {
  description = "NAT 게이트웨이 ID 목록"
  value       = aws_nat_gateway.main[*].id
}

output "nat_gateway_public_ips" {
  description = "NAT 게이트웨이 퍼블릭 IP"
  value       = aws_eip.nat[*].public_ip
}

# 라우팅 테이블 출력
output "public_route_table_id" {
  description = "퍼블릭 라우팅 테이블 ID"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "프라이빗 라우팅 테이블 ID 목록"
  value       = aws_route_table.private[*].id
}

output "db_route_table_id" {
  description = "DB 라우팅 테이블 ID"
  value       = aws_route_table.db.id
}

# DB 서브넷 그룹 출력
output "db_subnet_group_name" {
  description = "DB 서브넷 그룹 이름"
  value       = aws_db_subnet_group.main.name
}

output "db_subnet_group_arn" {
  description = "DB 서브넷 그룹 ARN"
  value       = aws_db_subnet_group.main.arn
}

# VPC Endpoint 출력 (S3만 유지)
output "vpc_endpoint_s3_id" {
  description = "S3 VPC 엔드포인트 ID"
  value       = aws_vpc_endpoint.s3.id
}
