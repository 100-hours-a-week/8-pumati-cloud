# VPC 정보
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC의 CIDR 블록"
  value       = module.vpc.vpc_cidr_block
}

# 퍼블릭 서브넷 구성 요소
output "public_subnet_id" {
  description = "퍼블릭 서브넷 ID"
  value       = module.vpc.public_subnet_ids[0]
}

output "public_subnet_cidr" {
  description = "퍼블릭 서브넷 CIDR 블록"
  value       = module.vpc.public_subnet_cidr_blocks[0]
}

output "public_route_table_id" {
  description = "퍼블릭 라우팅 테이블 ID"
  value       = module.vpc.public_route_table_id
}

output "internet_gateway_id" {
  description = "인터넷 게이트웨이 ID"
  value       = module.vpc.internet_gateway_id
}

# VPC Peering 정보
output "vpc_peering_connection_id" {
  value = module.vpc_peering_shared_to_prod.vpc_peering_connection_id
}
