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

output "public_subnet_cidrs" {
  description = "퍼블릭 서브넷 CIDR 블록 리스트"
  value       = module.vpc.public_subnet_cidr_blocks
}

output "public_route_table_id" {
  description = "퍼블릭 라우팅 테이블 ID"
  value       = module.vpc.public_route_table_id
}

# ----------------------------------------------------------------------------------------------------------------------
# 서비스 서브넷 (선택적 구성 요소)
# ----------------------------------------------------------------------------------------------------------------------
output "service_subnet_ids" {
  description = "서비스 서브넷 ID 리스트 (enable_service_subnet=true일 때만)"
  value = module.vpc.service_subnet_ids
}

output "service_subnet_cidr_blocks" {
  description = "서비스 서브넷 CIDR 블록 리스트(enable_service_subnet=true일 때만)"
  value = module.vpc.service_subnet_cidr_blocks
}

output "service_route_table_ids" {
  description = "서비스 라우팅 테이블 ID 리스트 (enable_service_subnet=true일 때만)"
  value = module.vpc.service_route_table_ids
}

# ----------------------------------------------------------------------------------------------------------------------
# DB 서브넷 (선택적 구성 요소)
# ----------------------------------------------------------------------------------------------------------------------
output "db_subnet_ids" {
  description = "DB 서브넷 ID 리스트 (enable_db_subnet=true일 때만)"
  value = module.vpc.db_subnet_ids
}

output "db_subnet_cidr_blocks" {
  description = "DB 서브넷 CIDR 블록 리스트 (enable_db_subnet=true일 때만)"
  value = module.vpc.db_subnet_cidr_blocks
}

output "db_route_table_ids" {
  description = "DB 라우팅 테이블 ID 리스트 (enable_db_subnet=true일 때만)"
  value = module.vpc.db_route_table_ids
}
# ----------------------------------------------------------------------------------------------------------------------
# NAT 인스턴스 정보
# ----------------------------------------------------------------------------------------------------------------------
output "nat_instance_id" {
  value = module.nat_instance.instance_id
}

output "nat_instance_public_ip" {
  value = module.nat_instance.public_ip
}
