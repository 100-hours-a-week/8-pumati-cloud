# ----------------------------------------------------------------------------------------------------------------------
# ALB 생성 (Frontend + Backend 통합)
# ----------------------------------------------------------------------------------------------------------------------
module "alb" {
  source = "../../common/module/alb"

  project_name = local.project_name
  environment  = local.environment
  service_name = "alb"
  tags         = local.common_tags

  vpc_id             = local.vpc_id
  public_subnet_ids  = local.public_subnet_ids
  security_group_ids = [local.alb_sg_id]

  internal                   = false
  enable_deletion_protection = false
  idle_timeout               = 60

  target_groups = {
    frontend = {
      port        = 3000
      health_path = "/"
    },
    backend = {
      port        = 8080
      health_path = "/api/actuator/health"
    }
  }
}

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
    frontend = {
      priority         = 20
      host_headers     = ["tebutebu.com"]
      path_patterns    = ["/*"]
      target_group_arn = module.alb.target_group_arns["frontend"]
    },
    backend = {
      priority         = 10
      host_headers     = ["tebutebu.com"]
      path_patterns    = [
        "/api/*",
        "/oauth2/*",
        "/actuator/*",
        "/api/*/chatbot*"
      ]
      target_group_arn = module.alb.target_group_arns["backend"]
    }
  }
}
