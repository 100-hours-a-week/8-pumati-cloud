module "openvpn_instance" {
  source = "../../common/module/instance"

  project_name  = local.project_name
  environment   = local.environment
  tags          = local.common_tags
  instance_name = "openvpn"

  instance_ami           = "ami-09a093fa2e3bfca5a"
  instance_type          = "t2.micro"
  instance_key_name      = "pumati-full-master"
  # iam_instance_profile   = X
  subnet_id              = local.public_subnet_id
  security_group_ids     = [local.openvpn_sg_id]

  root_volume_size       = 20
  root_volume_type       = "gp2"

  # user_data              = file("${path.module}/scripts/openvpn-user-data.sh")

  enable_monitoring             = true
  disable_api_termination       = false
  shutdown_behavior             = "stop"

  enable_eip = false
}