output "certificate_arn" {
  value = aws_acm_certificate.this.arn
  description = "생성된 ACM 인증서의 ARN"
}

output "domain_validation_options" {
  value = aws_acm_certificate.this.domain_validation_options
  description = "인증서 검증을 위한 도메인 검증 옵션"
}

output "certificate_status" {
  value = aws_acm_certificate.this.status
  description = "ACM 인증서의 현재 상태"
}
