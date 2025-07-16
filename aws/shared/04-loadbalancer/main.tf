# ---------------------------------------------------------------------------------------------------------------------
# ALB
# ---------------------------------------------------------------------------------------------------------------------
module "alb" {
  source = "../../common/module/alb"

  project_name        = local.project_name
  environment         = local.environment
  service_name        = "alb"
  tags                = local.common_tags

  vpc_id              = local.vpc_id
  public_subnet_ids   = local.public_subnet_ids
  security_group_ids  = [local.alb_sg_id]

  internal                    = false
  enable_deletion_protection  = false
  idle_timeout                = 60

  target_groups = {
    jenkins = {
      port        = 8080
      health_path = "/"
      matcher     = "200-499" # Jenkins는 로그인하지 않은 상태로 / 접근 시 403을 줌
    },
    prometheus = {
      port        = 9090
      health_path = "/"
      matcher     = "200-399"
    },
    grafana = {
      port        = 3000
      health_path = "/"
      matcher     = "200-399"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ALB Listener
# ---------------------------------------------------------------------------------------------------------------------
module "alb_listener" {
  source = "../../common/module/alb_listener"

  project_name  = local.project_name
  environment   = local.environment
  service_name  = "alb"
  tags          = local.common_tags

  load_balancer_arn = module.alb.alb_arn
  certificate_arn   = local.certificate_arn

  enable_https    = true
  enable_redirect = true

  listener_rules = {
    jenkins = {
      priority         = 10
      host_headers     = ["jenkins.tebutebu.com"]
      path_patterns    = ["/*"]
      target_group_arn = module.alb.target_group_arns["jenkins"]
    },
    prometheus = {
      priority         = 20
      host_headers     = ["prometheus.tebutebu.com"]
      path_patterns    = ["/*"]
      target_group_arn = module.alb.target_group_arns["prometheus"]
    },
    grafana = {
      priority         = 30
      host_headers     = ["grafana.tebutebu.com"]
      path_patterns    = ["/*"]
      target_group_arn = module.alb.target_group_arns["grafana"]
    }
  }
}
