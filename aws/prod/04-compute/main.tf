module "frontend_instance" {
  source = "../../module/instance"

  # 공통
  project_name  = local.project_name
  environment   = local.environment
  tags          = local.common_tags
  instance_name = "frontend"

  # 인스턴스 고유 설정
  instance_ami           = "ami-0d5bb3742db8fc264"
  instance_type          = "t3.small"
  instance_key_name      = "pumati-full-master"
  iam_instance_profile   = local.frontend_instance_profile_name
  subnet_id              = local.public_subnet_id
  security_group_ids     = [local.frontend_sg_id]

  root_volume_size       = 20
  root_volume_type       = "gp3"

  user_data              = file("${path.module}/scripts/frontend-user-data.sh")

  enable_monitoring             = true
  disable_api_termination       = false
  shutdown_behavior             = "stop"

  enable_eip = true
}

module "backend_instance" {
  source = "../../module/instance"

  project_name  = local.project_name
  environment   = local.environment
  tags          = local.common_tags
  instance_name = "backend"

  instance_ami           = "ami-0d5bb3742db8fc264"
  instance_type          = "t3.small"
  instance_key_name      = "pumati-full-master"
  iam_instance_profile   = local.backend_instance_profile_name
  subnet_id              = local.public_subnet_id
  security_group_ids     = [local.backend_sg_id]

  root_volume_size       = 20
  root_volume_type       = "gp3"

  user_data              = file("${path.module}/scripts/backend-user-data.sh")

  enable_monitoring             = true
  disable_api_termination       = false
  shutdown_behavior             = "stop"

  enable_eip = false
}

module "jenkins_instance" {
  source = "../../module/instance"

  project_name  = local.project_name
  environment   = local.environment
  tags          = local.common_tags
  instance_name = "jenkins"

  instance_ami           = "ami-0d5bb3742db8fc264"
  instance_type          = "t3.small"
  instance_key_name      = "pumati-full-master"
  iam_instance_profile   = local.jenkins_instance_profile_name
  subnet_id              = local.public_subnet_id
  security_group_ids     = [local.jenkins_sg_id]

  root_volume_size       = 30
  root_volume_type       = "gp3"

  user_data              = file("${path.module}/scripts/jenkins-user-data.sh")

  enable_monitoring             = true
  disable_api_termination       = false
  shutdown_behavior             = "stop"

  enable_eip = false
}
