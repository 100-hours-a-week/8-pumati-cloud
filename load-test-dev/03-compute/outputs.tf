# load-test-dev/03-compute/outputs.tf
# Compute 리소스 출력 변수

# ===============================
# Load Balancer URLs
# ===============================

# NLB URLs (외부 접근용)
output "backend_nlb_dns" {
  description = "백엔드 NLB DNS 이름"
  value       = var.enable_nlb ? aws_lb.backend_nlb[0].dns_name : null
}

output "frontend_nlb_dns" {
  description = "프론트엔드 NLB DNS 이름"
  value       = var.enable_nlb ? aws_lb.frontend_nlb[0].dns_name : null
}

# ALB URLs
output "backend_alb_dns" {
  description = "백엔드 ALB DNS 이름"
  value       = aws_lb.backend_alb.dns_name
}

output "frontend_alb_dns" {
  description = "프론트엔드 ALB DNS 이름"
  value       = aws_lb.frontend_alb.dns_name
}

# 실제 접속 URL (NLB 사용시 NLB, 아니면 ALB)
output "backend_url" {
  description = "백엔드 접속 URL"
  value       = var.enable_nlb ? "http://${aws_lb.backend_nlb[0].dns_name}" : "http://${aws_lb.backend_alb.dns_name}"
}

output "frontend_url" {
  description = "프론트엔드 접속 URL"
  value       = var.enable_nlb ? "http://${aws_lb.frontend_nlb[0].dns_name}" : "http://${aws_lb.frontend_alb.dns_name}"
}

# ===============================
# Auto Scaling Groups
# ===============================

output "backend_asg_name" {
  description = "백엔드 Auto Scaling Group 이름"
  value       = aws_autoscaling_group.backend.name
}

output "frontend_asg_name" {
  description = "프론트엔드 Auto Scaling Group 이름"
  value       = aws_autoscaling_group.frontend.name
}

output "backend_asg_arn" {
  description = "백엔드 Auto Scaling Group ARN"
  value       = aws_autoscaling_group.backend.arn
}

output "frontend_asg_arn" {
  description = "프론트엔드 Auto Scaling Group ARN"
  value       = aws_autoscaling_group.frontend.arn
}

# ===============================
# Launch Templates
# ===============================

output "backend_launch_template_id" {
  description = "백엔드 Launch Template ID"
  value       = aws_launch_template.backend.id
}

output "frontend_launch_template_id" {
  description = "프론트엔드 Launch Template ID"
  value       = aws_launch_template.frontend.id
}

# ===============================
# Target Groups
# ===============================

output "backend_target_group_arn" {
  description = "백엔드 Target Group ARN"
  value       = aws_lb_target_group.backend.arn
}

output "frontend_target_group_arn" {
  description = "프론트엔드 Target Group ARN"
  value       = aws_lb_target_group.frontend.arn
}

# ===============================
# Security Groups
# ===============================

output "backend_instance_sg_id" {
  description = "백엔드 인스턴스 보안 그룹 ID"
  value       = aws_security_group.backend_instances.id
}

output "frontend_instance_sg_id" {
  description = "프론트엔드 인스턴스 보안 그룹 ID"
  value       = aws_security_group.frontend_instances.id
}

output "backend_alb_sg_id" {
  description = "백엔드 ALB 보안 그룹 ID"
  value       = aws_security_group.backend_alb.id
}

output "frontend_alb_sg_id" {
  description = "프론트엔드 ALB 보안 그룹 ID"
  value       = aws_security_group.frontend_alb.id
}

# ===============================
# CloudWatch Log Groups
# ===============================

output "backend_log_group_name" {
  description = "백엔드 CloudWatch 로그 그룹 이름"
  value       = aws_cloudwatch_log_group.backend_logs.name
}

output "frontend_log_group_name" {
  description = "프론트엔드 CloudWatch 로그 그룹 이름"
  value       = aws_cloudwatch_log_group.frontend_logs.name
}

# ===============================
# 구성 정보
# ===============================

output "compute_configuration" {
  description = "Compute 구성 정보"
  value = {
    nlb_enabled           = var.enable_nlb
    backend_asg_config = {
      min      = var.backend_asg_min
      max      = var.backend_asg_max
      desired  = var.backend_asg_desired
    }
    frontend_asg_config = {
      min      = var.frontend_asg_min
      max      = var.frontend_asg_max
      desired  = var.frontend_asg_desired
    }
    instance_type         = var.instance_type
    backend_ami          = var.custom_backend_ami
    frontend_ami         = var.custom_frontend_ami
    detailed_monitoring  = var.enable_detailed_monitoring
  }
}

# ===============================
# 로드 테스트 가이드
# ===============================

output "load_test_endpoints" {
  description = "로드테스트용 엔드포인트 정보"
  value = {
    architecture = var.enable_nlb ? "NLB + ALB" : "ALB Only"
    
    backend = {
      primary_url = var.enable_nlb ? "http://${aws_lb.backend_nlb[0].dns_name}" : "http://${aws_lb.backend_alb.dns_name}"
      alb_url     = "http://${aws_lb.backend_alb.dns_name}"
      health_check = var.enable_nlb ? "http://${aws_lb.backend_nlb[0].dns_name}/health" : "http://${aws_lb.backend_alb.dns_name}/health"
      api_base    = var.enable_nlb ? "http://${aws_lb.backend_nlb[0].dns_name}/api" : "http://${aws_lb.backend_alb.dns_name}/api"
    }
    
    frontend = {
      primary_url = var.enable_nlb ? "http://${aws_lb.frontend_nlb[0].dns_name}" : "http://${aws_lb.frontend_alb.dns_name}"
      alb_url     = "http://${aws_lb.frontend_alb.dns_name}"
      health_check = var.enable_nlb ? "http://${aws_lb.frontend_nlb[0].dns_name}/" : "http://${aws_lb.frontend_alb.dns_name}/"
    }
    
    scaling_commands = {
      scale_backend_up   = "aws autoscaling update-auto-scaling-group --auto-scaling-group-name ${aws_autoscaling_group.backend.name} --desired-capacity 10"
      scale_frontend_up  = "aws autoscaling update-auto-scaling-group --auto-scaling-group-name ${aws_autoscaling_group.frontend.name} --desired-capacity 10"
      scale_backend_down = "aws autoscaling update-auto-scaling-group --auto-scaling-group-name ${aws_autoscaling_group.backend.name} --desired-capacity 3"
      scale_frontend_down = "aws autoscaling update-auto-scaling-group --auto-scaling-group-name ${aws_autoscaling_group.frontend.name} --desired-capacity 3"
    }
    
    monitoring = {
      backend_logs  = aws_cloudwatch_log_group.backend_logs.name
      frontend_logs = aws_cloudwatch_log_group.frontend_logs.name
      cloudwatch_namespace_backend  = "LoadTest/Backend"
      cloudwatch_namespace_frontend = "LoadTest/Frontend"
    }
  }
}

# ===============================
# 대회 대비 확장 가이드
# ===============================

output "competition_scaling_guide" {
  description = "대회 당일 확장 가이드"
  value = {
    current_capacity = {
      backend_instances  = var.backend_asg_desired
      frontend_instances = var.frontend_asg_desired
      total_instances    = var.backend_asg_desired + var.frontend_asg_desired
    }
    
    quick_scaling = {
      variables_to_change = [
        "backend_asg_desired",
        "frontend_asg_desired", 
        "backend_asg_max",
        "frontend_asg_max"
      ]
      terraform_command = "terraform apply -var='backend_asg_desired=10' -var='frontend_asg_desired=10'"
    }
    
    emergency_scaling = {
      aws_cli_backend  = "aws autoscaling update-auto-scaling-group --auto-scaling-group-name ${aws_autoscaling_group.backend.name} --desired-capacity 15"
      aws_cli_frontend = "aws autoscaling update-auto-scaling-group --auto-scaling-group-name ${aws_autoscaling_group.frontend.name} --desired-capacity 15"
    }
    
    performance_tiers = {
      light_load = {
        backend_instances  = 3
        frontend_instances = 3
        estimated_rps     = "1000-5000"
      }
      medium_load = {
        backend_instances  = 5
        frontend_instances = 5
        estimated_rps     = "5000-15000"
      }
      heavy_load = {
        backend_instances  = 10
        frontend_instances = 10
        estimated_rps     = "15000-50000"
      }
      extreme_load = {
        backend_instances  = 15
        frontend_instances = 15
        estimated_rps     = "50000+"
        note = "NLB + ALB 조합으로 최대 성능 발휘"
      }
    }
  }
} 