data "aws_route53_zone" "this" {
  name         = var.zone_name
  private_zone = false
}

resource "aws_route53_record" "this" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.record_name
  type    = "A"

  alias {
    name                   = var.alias_name     # ALB의 DNS name
    zone_id                = var.alias_zone_id  # ALB의 zone ID
    evaluate_target_health = true
  }
}
