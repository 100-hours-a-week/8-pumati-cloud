output "record_fqdn" {
  description = "생성된 Route 53 레코드의 전체 도메인 이름"
  value       = aws_route53_record.this.fqdn
}
