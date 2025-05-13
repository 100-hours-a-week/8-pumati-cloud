# ------------------------------------------------------------
# VPC 출력값
# ------------------------------------------------------------
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_id" {
  description = "퍼블릭 서브넷 ID"
  value       = module.vpc.public_subnet_id
}

output "public_route_table_id" {
  description = "퍼블릭 라우팅 테이블 ID"
  value       = module.vpc.public_route_table_id
}

output "internet_gateway_id" {
  description = "인터넷 게이트웨이 ID"
  value       = module.vpc.internet_gateway_id
}

output "vpc_cidr" {
  description = "VPC CIDR 블록"
  value       = module.vpc.vpc_cidr_block
}

# ------------------------------------------------------------
# 프론트엔드 보안 그룹 출력값
# ------------------------------------------------------------
output "frontend_sg_id" {
  description = "프론트엔드 보안 그룹 ID"
  value       = module.security_group.frontend_sg_id
}

# ------------------------------------------------------------
# 백엔드 보안 그룹 출력값
# ------------------------------------------------------------
output "backend_sg_id" {
  description = "백엔드 보안 그룹 ID"
  value       = module.security_group.backend_sg_id
}

# ------------------------------------------------------------
# DB 보안 그룹 출력값
# ------------------------------------------------------------
output "db_sg_id" {
  description = "DB 보안 그룹 ID"
  value       = module.security_group.db_sg_id
} 