module "frontend_ecr" {
  source        = "../../common/module/ECR"
  project_name  = local.project_name      # 예: "pumati"
  environment   = local.environment       # 예: "prod"
  service_name  = "frontend"
  tags          = local.common_tags
}

module "backend_ecr" {
  source        = "../../common/module/ECR"
  project_name  = local.project_name
  environment   = local.environment
  service_name  = "backend"
  tags          = local.common_tags
}