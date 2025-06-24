output "alb_dns_name" {
  description = "ALB의 DNS 이름"
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "ALB의 Route 53 zone ID"
  value       = module.alb.alb_zone_id
}

output "alb_arn" {
  description = "ALB ARN"
  value       = module.alb.alb_arn
}

output "frontend_target_group_arn" {
  value = module.alb.frontend_target_group_arn
}

output "backend_target_group_arn" {
  value = module.alb.backend_target_group_arn
}

output "https_listener_arn" {
  description = "443 HTTPS 리스너 ARN"
  value       = module.alb_listener.https_listener_arn
}

output "http_listener_arn" {
  description = "80 HTTP 리디렉션 리스너 ARN"
  value       = module.alb_listener.http_listener_arn
}