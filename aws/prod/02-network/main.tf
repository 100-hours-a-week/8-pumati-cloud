module "vpc" {
  source = "../../module/vpc"

  project_name = local.project_name
  environment  = local.environment
  tags         = local.common_tags

  vpc_cidr              = "10.3.0.0/16"
  public_subnet_cidr    = "10.3.0.0/24"
  service_subnet_cidr   = "10.3.1.0/24"
  db_subnet_cidr        = "10.3.2.0/24"
  az                    = "ap-northeast-2a"
  map_public_ip_on_launch = true

  enable_service_subnet = false
  enable_db_subnet      = false
}
