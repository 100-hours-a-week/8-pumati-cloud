output "frontend_target_group_arn" {
  value = module.alb.frontend_target_group_arn
}

output "backend_target_group_arn" {
  value = module.alb.backend_target_group_arn
}

output "alb_arn" {
  value = module.alb.alb_arn
}

output "https_listener_arn" {
  description = "443 HTTPS 리스너 ARN"
  value       = module.alb_listener.https_listener_arn
}

output "http_listener_arn" {
  description = "80 HTTP 리디렉션 리스너 ARN"
  value       = module.alb_listener.http_listener_arn
}