module "vpc" {
  source = "../../common/module/vpc"

  project_name = local.project_name
  environment  = local.environment
  tags         = local.common_tags

  vpc_cidr              = "10.0.0.0/16"
  azs                   = ["a", "c"]
  public_subnet_cidrs   = ["10.0.1.0/24", "10.0.10.0/24"]
  # service_subnet_cidrs  = ["10.0.2.0/24", "10.0.20.0/24"]
  # db_subnet_cidrs       = ["10.0.3.0/24", "10.0.30.0/24"]

  enable_service_subnet   = false
  enable_db_subnet        = false

  public_subnet_map_public_ip  = true
  # service_subnet_map_public_ip = false
  # db_subnet_map_public_ip      = false
}

