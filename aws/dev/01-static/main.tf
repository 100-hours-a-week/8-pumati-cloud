# Route53 호스팅 존 데이터 소스 (기존 호스팅 존이 있다고 가정)
data "aws_route53_zone" "this" {
  name = local.domain_name
  private_zone = false
}

# ACM 인증서 생성
module "acm" {
  source = "../../common/modules/acm"

  domain_name               = local.domain_name
  subject_alternative_names = ["*.${local.domain_name}"]
  zone_id                   = data.aws_route53_zone.this.zone_id
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-certificate"
    }
  )
}
