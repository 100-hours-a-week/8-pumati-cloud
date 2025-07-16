module "route53_grafana" {
  source = "../../common/module/route53_alb"

  zone_name        = "tebutebu.com"
  record_name      = "grafana.tebutebu.com"
  alias_name       = local.alb_dns_name    # ALB DNS 이름
  alias_zone_id    = local.alb_zone_id     # ALB Zone ID
}
module "route53_jenkins" {
  source = "../../common/module/route53_alb"

  zone_name        = "tebutebu.com"
  record_name      = "jenkins.tebutebu.com"
  alias_name       = local.alb_dns_name
  alias_zone_id    = local.alb_zone_id
}

module "route53_prometheus" {
  source = "../../common/module/route53_alb"

  zone_name        = "tebutebu.com"
  record_name      = "prometheus.tebutebu.com"
  alias_name       = local.alb_dns_name
  alias_zone_id    = local.alb_zone_id
}

module "route53_kibana" {
  source = "../../common/module/route53_alb"

  zone_name        = "tebutebu.com"
  record_name      = "kibana.tebutebu.com"
  alias_name       = local.alb_dns_name
  alias_zone_id    = local.alb_zone_id
}