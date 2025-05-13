# ------------------------------------------------------------
# VPC 모듈
# ------------------------------------------------------------
module "vpc" {
  source = "../../common/module/vpc"

  project_name = local.project_name
  environment  = local.environment
  tags         = local.common_tags

  vpc_cidr                  = var.vpc_cidr
  vpc_az                    = var.vpc_az
  vpc_public_subnets_a_cidr = var.vpc_public_subnets_a_cidr
}

# ------------------------------------------------------------
# 보안 그룹 모듈
# ------------------------------------------------------------
module "security_group" {
  source = "../../common/module/security_group"

  project_name = local.project_name
  environment  = local.environment
  tags         = local.common_tags

  vpc_id       = module.vpc.vpc_id
  vpc_cidr     = module.vpc.vpc_cidr_block
}