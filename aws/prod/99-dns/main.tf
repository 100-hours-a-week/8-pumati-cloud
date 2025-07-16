module "route53_test_subdomain" {
  source = "../../common/module/route53_alb"

  zone_name       = "tebutebu.com"
  record_name     = "test.tebutebu.com"
  alias_name      = local.alb_dns_name
  alias_zone_id   = local.alb_zone_id
}
