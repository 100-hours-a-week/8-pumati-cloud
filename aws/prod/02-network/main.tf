module "vpc" {
  source = "../../common/module/vpc"

  project_name = local.project_name
  environment  = local.environment
  tags         = local.common_tags

  vpc_cidr              = "10.3.0.0/16"
  public_subnet_cidr    = "10.3.0.0/24"
  service_subnet_cidr   = "10.3.1.0/24"
  db_subnet_cidr        = "10.3.2.0/24"
  az                    = "ap-northeast-2a"

  enable_service_subnet   = true
  enable_db_subnet        = true

  public_subnet_map_public_ip  = true
  service_subnet_map_public_ip = false
  db_subnet_map_public_ip      = false
}

# ----------------------------------------------------------------------------------------------------------------------
# NAT 인스턴스 구성 
# ----------------------------------------------------------------------------------------------------------------------
module "nat_sg" {
  source        = "../../common/module/sg"

  # 공통 값
  project_name  = local.project_name
  environment   = local.environment
  tags          = local.common_tags
  service_name  = "nat"

  # 리소스 고유값
  name          = "${local.project_name}-${local.environment}-nat-sg"
  description   = "NAT 인스턴스용 보안 그룹"
  vpc_id        = module.vpc.vpc_id

  # 인바운드 규칙: 없음 (NAT 인스턴스는 외부 요청 수신 안 함)
  ingress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "SSH access for NAT"
    }
  ]
  # egress는 모듈 기본값이 ["0.0.0.0/0"]이라면 따로 안 써도 됨
}

module "nat_instance" {
  source = "../../common/module/instance"

  # 공통
  project_name  = local.project_name
  environment   = local.environment
  tags          = local.common_tags
  instance_name = "nat"

  # 인스턴스 고유 설정
  instance_ami           = "ami-01ad0c7a4930f0e43"
  instance_type          = "t2.micro"
  instance_key_name      = "pumati-full-master"
  iam_instance_profile   = null
  subnet_id              = module.vpc.public_subnet_id 
  security_group_ids     = [module.nat_sg.security_group_id]

  root_volume_size       = 8
  root_volume_type       = "gp3"

  user_data              = null

  enable_monitoring             = false
  disable_api_termination       = false
  shutdown_behavior             = "stop"

  enable_eip = true
  source_dest_check = false  # NAT 인스턴스는 패킷 포워딩을 위해 false로 설정
}

# ----------------------------------------------------------------------------------------------------------------------
# NAT 라우트 연결
# ----------------------------------------------------------------------------------------------------------------------
module "nat_route_to_service" {
  source = "../../common/module/nat_route_association"

  route_table_id            = module.vpc.service_route_table_id
  nat_network_interface_id  = module.nat_instance.primary_network_interface_id
}

module "nat_route_to_db" {
  source = "../../common/module/nat_route_association"

  route_table_id            = module.vpc.db_route_table_id
  nat_network_interface_id  = module.nat_instance.primary_network_interface_id
}
