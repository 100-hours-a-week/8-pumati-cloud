# modules/vpc/outputs.tf
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "VPC CIDR 블록"
  value       = aws_vpc.this.cidr_block
}

output "internet_gateway_id" {
  description = "인터넷 게이트웨이 ID"
  value       = aws_internet_gateway.this.id
}

# ----------------------------------------------------------------------------------------------------------------------
# 퍼블릭 서브넷
# ----------------------------------------------------------------------------------------------------------------------
output "public_subnet_ids" {
  description = "퍼블릭 서브넷 ID 목록"
  value       = aws_subnet.public[*].id
}

output "public_subnet_cidr_blocks" {
  description = "퍼블릭 서브넷 CIDR 블록 목록"
  value       = aws_subnet.public[*].cidr_block
}
output "public_route_table_id" {
  description = "퍼블릭 라우팅 테이블 ID"
  value       = aws_route_table.public.id
}

# ----------------------------------------------------------------------------------------------------------------------
# 서비스 서브넷
# ----------------------------------------------------------------------------------------------------------------------
output "service_subnet_ids" {
  description = "서비스 서브넷 ID 리스트 (enable_service_subnet=true일 때만)"
  value       = var.enable_service_subnet ? aws_subnet.service[*].id : []
}

output "service_subnet_cidr_blocks" {
  description = "서비스 서브넷 CIDR 블록 리스트 (enable_service_subnet=true일 때만)"
  value       = var.enable_service_subnet ? aws_subnet.service[*].cidr_block : []
}

output "service_route_table_ids" {
  description = "서비스 라우팅 테이블 ID 리스트 (enable_service_subnet=true일 때만)"
  value       = var.enable_service_subnet ? aws_route_table.service[*].id : []
}

# ----------------------------------------------------------------------------------------------------------------------
# DB 서브넷
# ----------------------------------------------------------------------------------------------------------------------
output "db_subnet_ids" {
  description = "DB 서브넷 ID 리스트 (enable_db_subnet=true일 때만)"
  value       = var.enable_db_subnet ? aws_subnet.db[*].id : []
}

output "db_subnet_cidr_blocks" {
  description = "DB 서브넷 CIDR 블록 리스트 (enable_db_subnet=true일 때만)"
  value       = var.enable_db_subnet ? aws_subnet.db[*].cidr_block : []
}

output "db_route_table_ids" {
  description = "DB 라우팅 테이블 ID 리스트 (enable_db_subnet=true일 때만)"
  value       = var.enable_db_subnet ? aws_route_table.db[*].id : []
}
