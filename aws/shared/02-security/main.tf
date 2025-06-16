module "openvpn_sg" {
  source        = "../../common/module/sg"

  # 공통 값
  project_name  = local.project_name
  environment   = local.environment
  tags          = local.common_tags
  service_name  = "openvpn"

  # 리소스 고유값
  name          = "${local.project_name}-${local.environment}-openvpn-sg"
  description   = "OpenVPN 서비스용 보안 그룹"
  vpc_id        = local.vpc_id

  # 인바운드 규칙
  ingress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["211.244.225.211/32", "10.3.0.0/16"]
      description = "SSH"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["211.244.225.211/32"]
      description = "HTTPS"
    },
    {
      from_port   = 943
      to_port     = 943
      protocol    = "tcp"
      cidr_blocks = ["211.244.225.211/32"]
      description = "OpenVPN Admin Web Interface"
    },
    {
      from_port   = 945
      to_port     = 945
      protocol    = "tcp"
      cidr_blocks = ["211.244.225.211/32"]
      description = "OpenVPN Admin Web Interface (Alternative)"
    },
    {
      from_port   = 1194
      to_port     = 1194
      protocol    = "udp"
      cidr_blocks = ["211.244.225.211/32"]
      description = "OpenVPN"
    }
  ]
}