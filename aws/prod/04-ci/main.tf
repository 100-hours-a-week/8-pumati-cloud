# ------------------------------------------------------------
# Jenkins CI 인스턴스
# ------------------------------------------------------------
module "jenkins" {
  source = "../../common/module/instance"

  # 프로젝트 설정
  project_name = local.project_name
  environment  = local.environment
  tags         = local.common_tags

  # 인스턴스 설정
  instance_role     = "jenkins"
  instance_type     = var.instance_type
  instance_ami      = var.instance_ami_linux
  instance_key_name = var.instance_key_name

  # 네트워크 설정
  subnet_id = local.public_subnet_id

  # 스토리지 설정
  root_volume_size = var.root_volume_size
  root_volume_type = var.root_volume_type

  # 보안 그룹 설정
  jenkins_security_group_id = local.jenkins_sg_id
}