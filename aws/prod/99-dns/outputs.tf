output "record_fqdn" {
  description = "생성된 Route 53 레코드의 도메인 이름"
  value       = module.route53_test_subdomain.record_fqdn
}
