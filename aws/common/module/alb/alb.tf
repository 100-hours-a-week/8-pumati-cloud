resource "aws_lb" "this" {
  internal           = var.internal
  load_balancer_type = "application"

  security_groups = var.security_group_ids
  subnets         = var.public_subnet_ids

  enable_deletion_protection = var.enable_deletion_protection
  idle_timeout               = var.idle_timeout

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-${var.service_name}-alb"
  })
}

# 프론트 Target Group
resource "aws_lb_target_group" "frontend" {
  port        = var.frontend_port
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    path                = var.frontend_health_check_path
    protocol            = "HTTP"
    port                = "traffic-port"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-frontend-tg"
  })
}

# 백엔드 Target Group
resource "aws_lb_target_group" "backend" {
  port        = var.backend_port
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    path                = var.backend_health_check_path
    protocol            = "HTTP"
    port                = "traffic-port"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-backend-tg"
  })
}
