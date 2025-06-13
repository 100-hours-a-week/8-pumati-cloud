# shared vpc 생성
# 단일 가용 영역, 단일 퍼블릭 서브넷
# prod vpc와의 피어링 연결
module "vpc" {
  source = "../../common/module/vpc"

  project_name = local.project_name
  environment  = local.environment
  tags         = local.common_tags

  vpc_cidr              = "10.0.0.0/16"
  public_subnet_cidr    = "10.0.1.0/24"
  az                    = "ap-northeast-2a"

  public_subnet_map_public_ip  = true
}

module "vpc_peering_shared_to_prod" {
  source = "../../common/module/vpc-peering"

  project_name            = local.project_name
  environment             = local.environment
  tags                    = local.common_tags

  requester_vpc_id         = module.vpc.vpc_id
  requester_route_table_id = module.vpc.public_route_table_id

  accepter_vpc_id          = "vpc-059353dacd9e67556"
  destination_cidr_block   = "10.3.0.0/16"
}