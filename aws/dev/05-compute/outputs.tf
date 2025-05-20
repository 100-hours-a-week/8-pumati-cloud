output "alb_dns_name" {
  description = "ALB의 DNS 이름"
  value       = aws_lb.main.dns_name
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
