# Route53 호스팅 존 데이터 소스 (기존 호스팅 존이 있다고 가정)
# 이미 호스팅 영역이 만들어져 있음(사놨으니까)
data "aws_route53_zone" "this" {
  name         = "tebutebu.com"  # 부모 도메인
  private_zone = false
}

# ACM 인증서 생성 - 부하 테스트용 HTTPS 접속을 위해 필요
resource "aws_acm_certificate" "this" {
  domain_name               = local.domain_name
  subject_alternative_names = ["*.${local.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-certificate"
    }
  )
}

# ACM 인증서 DNS 검증 레코드 생성
resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.this.zone_id
}

# ACM 인증서 검증 완료 대기
resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation : record.fqdn]

  timeouts {
    create = "5m"
  }
}

# 현재 AWS 계정 ID 조회 (필요시 사용)
data "aws_caller_identity" "current" {}




