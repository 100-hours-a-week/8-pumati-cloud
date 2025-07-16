module "openvpn_instance" {
  source = "../../common/module/instance"

  project_name  = local.project_name
  environment   = local.environment
  tags          = local.common_tags
  service_name = "openvpn"

  instance_ami           = "ami-09a093fa2e3bfca5a"
  instance_type          = "t2.micro"
  instance_key_name      = "pumati-full-master"
  # iam_instance_profile   = X
  subnet_id              = local.public_subnet_ids
  security_group_ids     = [local.openvpn_sg_id]

  root_volume_size       = 20
  root_volume_type       = "gp2"

  # user_data              = file("${path.module}/scripts/openvpn-user-data.sh")

  enable_monitoring             = true
  disable_api_termination       = false
  shutdown_behavior             = "stop"

  enable_eip = true
}

module "management_instance" {
  source = "../../common/module/instance"

  project_name  = local.project_name
  environment   = local.environment
  tags          = local.common_tags
  service_name = "management"

  instance_ami           = "ami-0d5bb3742db8fc264"
  instance_type          = "t3.small"
  instance_key_name      = "pumati-full-master"
  iam_instance_profile   = local.management_instance_profile_name
  subnet_id              = local.public_subnet_ids
  security_group_ids     = [local.management_sg_id]

  root_volume_size       = 30
  root_volume_type       = "gp3"

  user_data              = file("${path.module}/scripts/management-user-data.sh")

  enable_monitoring             = true
  disable_api_termination       = false
  shutdown_behavior             = "stop"

  enable_eip = false
}

# ---------------------------------------------------------------------------------------------------------------------
# Target Group Attachment - EC2 인스턴스를 타겟 그룹에 연결
# ---------------------------------------------------------------------------------------------------------------------

module "jenkins_target_attachment" {
  source = "../../common/module/alb_target_attachment"

  target_group_arn = local.jenkins_target_group_arn
  target_id        = module.management_instance.instance_id
  port             = 8080
}

module "grafana_target_attachment" {
  source = "../../common/module/alb_target_attachment"

  target_group_arn = local.grafana_target_group_arn
  target_id        = module.management_instance.instance_id
  port             = 3000
}

module "prometheus_target_attachment" {
  source = "../../common/module/alb_target_attachment"

  target_group_arn = local.prometheus_target_group_arn
  target_id        = module.management_instance.instance_id
  port             = 9090
}