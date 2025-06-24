# ----------------------------------------------------------------------------------------------------------------------
# ALB 생성 (Frontend + Backend 통합)
# ----------------------------------------------------------------------------------------------------------------------
module "alb" {
  source = "../../common/module/alb"

  # 공통 변수
  project_name = local.project_name
  environment  = local.environment
  service_name = "alb"
  tags         = local.common_tags

  # 네트워크
  vpc_id             = local.vpc_id_test
  public_subnet_ids  = local.public_subnet_ids_test
  security_group_ids = [local.alb_sg_id]

  # ALB 설정
  internal                   = false
  enable_deletion_protection = false
  idle_timeout               = 60

  # 프론트 Target Group 설정
  frontend_port                = 3000
  frontend_health_check_path   = "/"

  # 백엔드 Target Group 설정
  backend_port                 = 8080
  backend_health_check_path    = "/api/actuator/health"
}

module "alb_listener" {
  source = "../../common/module/alb_listener"

  project_name  = local.project_name
  environment   = local.environment
  service_name  = "alb"
  tags          = local.common_tags

  load_balancer_arn          = module.alb.alb_arn
  certificate_arn            = local.certificate_arn
  default_target_group_arn   = module.alb.frontend_target_group_arn
  api_target_group_arn       = module.alb.backend_target_group_arn

  backend_path_patterns = [
    "/api/*",
    "/oauth2/*",
    "/api/*/chatbot*"
  ]

  enable_https   = true
  enable_redirect = true
}
