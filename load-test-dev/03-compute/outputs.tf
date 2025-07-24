# load-test-dev/03-compute/outputs.tf
# Compute 리소스 출력 변수 - 백엔드 전용

# ===============================
# Load Balancer URL
# ===============================

# 백엔드 ALB URL
output "backend_alb_dns" {
  description = "백엔드 ALB DNS 이름"
  value       = aws_lb.backend_alb.dns_name
}

# 백엔드 접속 URL
output "backend_url" {
  description = "백엔드 API 접속 URL"
  value       = "http://${aws_lb.backend_alb.dns_name}"
}

# API 엔드포인트
output "backend_api_url" {
  description = "백엔드 API 기본 URL"
  value       = "http://${aws_lb.backend_alb.dns_name}/api"
}

# 헬스체크 URL
output "backend_health_url" {
  description = "백엔드 헬스체크 URL"
  value       = "http://${aws_lb.backend_alb.dns_name}/health"
}

# ===============================
# Auto Scaling Group
# ===============================

output "backend_asg_name" {
  description = "백엔드 Auto Scaling Group 이름"
  value       = aws_autoscaling_group.backend.name
}

output "backend_asg_arn" {
  description = "백엔드 Auto Scaling Group ARN"
  value       = aws_autoscaling_group.backend.arn
}

# ===============================
# Launch Template
# ===============================

output "backend_launch_template_id" {
  description = "백엔드 Launch Template ID"
  value       = aws_launch_template.backend.id
}

# ===============================
# Target Group
# ===============================

output "backend_target_group_arn" {
  description = "백엔드 Target Group ARN"
  value       = aws_lb_target_group.backend.arn
}

# ===============================
# Security Groups
# ===============================

output "backend_instance_sg_id" {
  description = "백엔드 인스턴스 보안 그룹 ID"
  value       = aws_security_group.backend_instances.id
}

output "backend_alb_sg_id" {
  description = "백엔드 ALB 보안 그룹 ID"
  value       = aws_security_group.backend_alb.id
}

# ===============================
# CloudWatch Log Group
# ===============================

output "backend_log_group_name" {
  description = "백엔드 CloudWatch 로그 그룹 이름"
  value       = aws_cloudwatch_log_group.backend_logs.name
}

# ===============================
# 구성 정보
# ===============================

output "compute_configuration" {
  description = "Compute 구성 정보"
  value = {
    instance_count       = var.backend_instance_count
    instance_type        = var.instance_type
    backend_ami          = var.custom_backend_ami
    detailed_monitoring  = var.enable_detailed_monitoring
    auto_healing_enabled = true
    scaling_enabled      = false
  }
}

# ===============================
# 로드 테스트 정보
# ===============================

output "load_test_info" {
  description = "로드테스트용 정보"
  value = {
    architecture = "ALB + Fixed Instances with Auto Healing"
    
    backend = {
      url           = "http://${aws_lb.backend_alb.dns_name}"
      api_base      = "http://${aws_lb.backend_alb.dns_name}/api"
      health_check  = "http://${aws_lb.backend_alb.dns_name}/health"
      instance_count = var.backend_instance_count
    }
    
    monitoring = {
      log_group = aws_cloudwatch_log_group.backend_logs.name
      cloudwatch_namespace = "LoadTest/Backend"
    }
    
    auto_healing = {
      enabled = true
      asg_name = aws_autoscaling_group.backend.name
      health_check_grace_period = "300 seconds"
      min_healthy_percentage = "80%"
    }
  }
} 