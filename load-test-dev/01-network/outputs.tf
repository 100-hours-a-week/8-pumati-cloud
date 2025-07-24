# load-test/02-network/outputs.tf
# 네트워크 출력 변수 - Load Test 환경

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

# 퍼블릭 서브넷 출력
output "public_subnet_ids" {
  description = "퍼블릭 서브넷 ID 목록"
  value       = aws_subnet.public[*].id
}

output "public_subnet_cidrs" {
  description = "퍼블릭 서브넷 CIDR 블록 목록"
  value       = aws_subnet.public[*].cidr_block
}

# 가용 영역 출력
output "availability_zones" {
  description = "사용된 가용 영역"
  value       = data.aws_availability_zones.available.names
}

# 퍼블릭 라우팅 테이블 출력
output "public_route_table_id" {
  description = "퍼블릭 라우팅 테이블 ID"
  value       = aws_route_table.public.id
}

# S3 VPC Endpoint 출력
output "vpc_endpoint_s3_id" {
  description = "S3 VPC 엔드포인트 ID"
  value       = aws_vpc_endpoint.s3.id
}
