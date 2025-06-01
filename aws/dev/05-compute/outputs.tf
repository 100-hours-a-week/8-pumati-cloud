output "alb_dns_name" {
  description = "ALB의 DNS 이름"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "ALB의 호스팅 영역 ID"
  value       = aws_lb.main.zone_id
}

output "alb_arn" {
  description = "ALB의 ARN"
  value       = aws_lb.main.arn
}

output "frontend_target_group_arn" {
  description = "프론트엔드 대상 그룹 ARN"
  value       = aws_lb_target_group.frontend.arn
}

output "backend_target_group_arn" {
  description = "백엔드 대상 그룹 ARN"
  value       = aws_lb_target_group.backend.arn
}

output "frontend_asg_name" {
  description = "프론트엔드 오토스케일링 그룹 이름"
  value       = aws_autoscaling_group.frontend.name
}

output "backend_asg_name" {
  description = "백엔드 오토스케일링 그룹 이름"
  value       = aws_autoscaling_group.backend.name
}

output "alb_security_group_id" {
  description = "ALB 보안 그룹 ID"
  value       = aws_security_group.alb_sg.id
}

output "alb_url" {
  description = "ALB 접속 URL"
  value       = "http://${aws_lb.main.dns_name}"
}

output "route53_dev_domain" {
  description = "개발 환경 도메인"
  value       = aws_route53_record.dev_subdomain.fqdn
}

output "backend_env_secret_name" {
  description = "Backend .env file secret name"
  value       = aws_secretsmanager_secret.backend_env.name
}

output "backend_env_secret_arn" {
  description = "Backend .env file secret ARN"
  value       = aws_secretsmanager_secret.backend_env.arn
}

output "frontend_env_secret_name" {
  description = "Frontend .env file secret name"
  value       = aws_secretsmanager_secret.frontend_env.name
}

output "frontend_env_secret_arn" {
  description = "Frontend .env file secret ARN"
  value       = aws_secretsmanager_secret.frontend_env.arn
}