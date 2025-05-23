output "frontend_domain_fqdn" {
  description = "프론트엔드 서비스의 도메인 이름 (FQDN)"
  value       = module.route53_record.record_fqdn
}
