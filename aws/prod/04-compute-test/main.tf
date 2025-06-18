module "frontend_instance_test" {
  source = "../../common/module/instance"

  project_name  = local.project_name
  environment   = local.environment
  tags          = local.common_tags
  service_name = "frontend-test"

  instance_ami           = "ami-0d5bb3742db8fc264"
  instance_type          = "t3.small"
  instance_key_name      = "pumati-full-master"
  iam_instance_profile   = local.frontend_instance_profile_name
  subnet_id              = local.service_subnet_ids_test
  security_group_ids     = [local.frontend_sg_id]

  root_volume_size       = 20
  root_volume_type       = "gp3"

  user_data              = file("${path.module}/scripts/frontend-user-data.sh")

  enable_monitoring             = true
  disable_api_termination       = false
  shutdown_behavior             = "stop"

  enable_eip = false
}

module "backend_instance_test" {
  source = "../../common/module/instance"

  project_name  = local.project_name
  environment   = local.environment
  tags          = local.common_tags
  service_name = "backend-test"

  instance_ami           = "ami-0d5bb3742db8fc264"
  instance_type          = "t3.small"
  instance_key_name      = "pumati-full-master"
  iam_instance_profile   = local.backend_instance_profile_name
  subnet_id              = local.service_subnet_ids_test
  security_group_ids     = [local.backend_sg_id]

  root_volume_size       = 20
  root_volume_type       = "gp3"

  user_data              = file("${path.module}/scripts/backend-user-data.sh")

  enable_monitoring             = true
  disable_api_termination       = false
  shutdown_behavior             = "stop"

  enable_eip = false
}
