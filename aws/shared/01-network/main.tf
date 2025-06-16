# 1. shared vpc : 단일 가용 영역, 단일 퍼블릭 서브넷
# 2. prod vpc와의 피어링 연결
module "vpc" {
  source = "../../common/module/vpc"

  project_name = local.project_name
  environment  = local.environment
  tags         = local.common_tags

  vpc_cidr              = "10.0.0.0/16"
  public_subnet_cidr    = "10.0.0.0/24"
  service_subnet_cidr   = "10.3.1.0/24"
  db_subnet_cidr        = "10.3.2.0/24"
  az                    = "ap-northeast-2a"

  enable_service_subnet   = false
  enable_db_subnet        = false

  public_subnet_map_public_ip  = true
  service_subnet_map_public_ip = false
  db_subnet_map_public_ip      = false
}

# ----------------------------------------------------------------------------------------------------------------------
# prod vpc와의 피어링 연결
# ----------------------------------------------------------------------------------------------------------------------
module "vpc_peering_shared_to_prod" {
  source = "../../common/module/vpc_peering"

  project_name = local.project_name
  environment  = local.environment
  tags         = local.common_tags

  requester_vpc_id         = module.vpc.vpc_id
  requester_vpc_cidr       = "10.0.0.0/16"
  requester_route_table_id = module.vpc.public_route_table_id

  accepter_vpc_id          = "vpc-059353dacd9e67556"
  accepter_vpc_cidr        = "10.3.0.0/16"

  accepter_route_table_ids = compact([
    local.prod_network_public_route_table_id,
    local.prod_network_service_route_table_id,
    local.prod_network_db_route_table_id
  ])

  enable_reverse_route     = true
}
