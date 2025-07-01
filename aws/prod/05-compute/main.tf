module "frontend_instance" {
  source = "../../common/module/instance"

  project_name  = local.project_name
  environment   = local.environment
  tags          = local.common_tags
  service_name = "frontend"

  instance_ami           = "ami-0d5bb3742db8fc264"
  instance_type          = "t3.small"
  instance_key_name      = "pumati-full-master"
  iam_instance_profile   = local.frontend_instance_profile_name
  subnet_id              = local.service_subnet_ids
  security_group_ids     = [local.frontend_sg_id]

  root_volume_size       = 20
  root_volume_type       = "gp3"

  user_data              = file("${path.module}/scripts/frontend-user-data.sh")

  enable_monitoring             = true
  disable_api_termination       = false
  shutdown_behavior             = "stop"

  enable_eip = false
}

module "backend_instance" {
  source = "../../common/module/instance"

  project_name  = local.project_name
  environment   = local.environment
  tags          = local.common_tags
  service_name = "backend"

  instance_ami           = "ami-0d5bb3742db8fc264"
  instance_type          = "t3.small"
  instance_key_name      = "pumati-full-master"
  iam_instance_profile   = local.backend_instance_profile_name
  subnet_id              = local.service_subnet_ids
  security_group_ids     = [local.backend_sg_id]

  root_volume_size       = 20
  root_volume_type       = "gp3"

  user_data              = file("${path.module}/scripts/backend-user-data.sh")

  enable_monitoring             = true
  disable_api_termination       = false
  shutdown_behavior             = "stop"

  enable_eip = false
}

module "db_instance" {
  source = "../../common/module/instance"

  project_name  = local.project_name
  environment   = local.environment
  tags          = local.common_tags
  service_name  = "db"

  instance_ami           = "ami-0d5bb3742db8fc264"
  instance_type          = "t3.small"
  instance_key_name      = "pumati-full-master"
  iam_instance_profile   = local.db_instance_profile_name
  subnet_id              = local.db_subnet_ids
  security_group_ids     = [local.db_sg_id]

  root_volume_size       = 30
  root_volume_type       = "gp3"

  # db는 스크립트에 대회형 UI 있어서 그냥 수동으로 하는게 좋음 
  # user_data            = file("${path.module}/scripts/db-user-data.sh")

  enable_monitoring             = true
  disable_api_termination       = false
  shutdown_behavior             = "stop"

  enable_eip = false
}

#----------------------------------------------------------------------------------------------------------------------
# Target Group Attachment - EC2 인스턴스를 타겟 그룹에 연결
#----------------------------------------------------------------------------------------------------------------------

module "frontend_target_attachment" {
  source = "../../common/module/alb_target_attachment"

  target_group_arn = local.frontend_target_group_arn
  target_id        = module.frontend_instance.instance_id
  port             = 3000
}

module "backend_target_attachment" {
  source = "../../common/module/alb_target_attachment"

  target_group_arn = local.backend_target_group_arn
  target_id        = module.backend_instance.instance_id
  port             = 8080
}