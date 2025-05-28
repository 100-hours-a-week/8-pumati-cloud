# modules/route53/outputs.tf
output "record_fqdn" {
  description = "Route 53에 등록된 전체 도메인 이름 (FQDN)"
  value       = aws_route53_record.this.fqdn
}

output "record_value" {
  description = "등록된 IP 또는 값"
  value       = aws_route53_record.this.records
}
