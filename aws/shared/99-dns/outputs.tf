output "grafana_domain" {
  value = module.route53_grafana.record_fqdn
}

output "jenkins_domain" {
  value = module.route53_jenkins.record_fqdn
}

output "prometheus_domain" {
  value = module.route53_prometheus.record_fqdn
}

output "alb_dns_name" {
  value = local.alb_dns_name
}

output "alb_zone_id" {
  value = local.alb_zone_id
}