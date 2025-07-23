# ACM 인증서 관련 출력 - 부하 테스트용 HTTPS 접속에 필요
output "acm_certificate_arn" {
  description = "ACM 인증서 ARN"
  value       = aws_acm_certificate_validation.this.certificate_arn
}

output "acm_certificate_domain_name" {
  description = "ACM 인증서 도메인 이름"
  value       = aws_acm_certificate.this.domain_name
}

# AWS 계정 ID 정보 (필요시 사용)
output "aws_account_id" {
  description = "현재 AWS 계정 ID"
  value       = data.aws_caller_identity.current.account_id
}


