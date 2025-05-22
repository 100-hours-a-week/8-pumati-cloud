# VPC 정보
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "VPC의 CIDR 블록"
  value       = module.vpc.vpc_cidr_block
}

# 퍼블릭 서브넷 구성 요소
output "public_subnet_id" {
  description = "퍼블릭 서브넷 ID"
  value       = module.vpc.public_subnet_id
}

output "public_subnet_cidr" {
  description = "퍼블릭 서브넷의 CIDR 블록"
  value       = module.vpc.public_subnet_cidr
}

output "public_route_table_id" {
  description = "퍼블릭 라우팅 테이블 ID"
  value       = module.vpc.public_route_table_id
}

output "internet_gateway_id" {
  description = "인터넷 게이트웨이 ID"
  value       = module.vpc.internet_gateway_id
}

# 서비스 및 DB 서브넷 (선택적 구성 요소)
output "service_subnet_id" {
  description = "서비스 서브넷 ID (존재 시)"
  value       = module.vpc.service_subnet_id
}

output "db_subnet_id" {
  description = "DB 서브넷 ID (존재 시)"
  value       = module.vpc.db_subnet_id
}
