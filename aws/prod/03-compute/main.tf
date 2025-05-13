# ------------------------------------------------------------
# 프론트엔드 인스턴스
# ------------------------------------------------------------
module "frontend" {
  source = "../../common/module/instance"

  # 프로젝트 설정
  project_name = local.project_name
  environment  = local.environment
  tags         = local.common_tags

  # 인스턴스 설정
  instance_role     = "frontend"
  instance_type     = var.instance_type
  instance_ami      = var.instance_ami_linux
  instance_key_name = var.instance_key_name

  # 네트워크 설정
  subnet_id = local.public_subnet_id

  # 스토리지 설정
  root_volume_size = var.root_volume_size
  root_volume_type = var.root_volume_type

  # 보안 그룹 설정
  frontend_security_group_id = local.frontend_sg_id
}

# ------------------------------------------------------------
# 백엔드 인스턴스
# ------------------------------------------------------------
module "backend" {
  source = "../../common/module/instance"

  # 프로젝트 설정
  project_name = local.project_name
  environment  = local.environment
  tags         = local.common_tags

  # 인스턴스 설정
  instance_role     = "backend"
  instance_type     = var.instance_type
  instance_ami      = var.instance_ami_linux
  instance_key_name = var.instance_key_name

  # 네트워크 설정
  subnet_id = local.public_subnet_id

  # 스토리지 설정
  root_volume_size = var.root_volume_size
  root_volume_type = var.root_volume_type

  # 보안 그룹 설정
  backend_security_group_id = local.backend_sg_id
}
