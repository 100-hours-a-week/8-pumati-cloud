module "route53_record" {
  source = "../modules/route53"

  zone_name   = "tebutebu.com"
  record_name = "tebutebu.v2.com"
  record_type = "A"
  ttl         = 60
  records     = [local.frontend_public_ip]
}
