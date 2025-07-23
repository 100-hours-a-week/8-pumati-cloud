# ----------------------------------------------------------------------------------------------------------------------
# VPC 정보
# ----------------------------------------------------------------------------------------------------------------------
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC의 CIDR 블록"
  value       = module.vpc.vpc_cidr
}

output "internet_gateway_id" {
  description = "인터넷 게이트웨이 ID"
  value       = module.vpc.internet_gateway_id
}

# ----------------------------------------------------------------------------------------------------------------------
# 퍼블릭 서브넷 구성 요소
# ----------------------------------------------------------------------------------------------------------------------
output "public_subnet_ids" {
  description = "퍼블릭 서브넷 ID 리스트"
  value       = module.vpc.public_subnet_ids
}

output "public_subnet_cidr_blocks" {
  description = "퍼블릭 서브넷 CIDR 블록 리스트"
  value       = module.vpc.public_subnet_cidr_blocks
}

output "public_route_table_ids" {
  description = "퍼블릭 라우팅 테이블 ID"
  value       = module.vpc.public_route_table_ids
}
