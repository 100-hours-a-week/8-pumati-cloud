resource "aws_lb" "this" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = var.internal
  load_balancer_type = "application"

  security_groups = var.security_group_ids
  subnets         = var.public_subnet_ids

  enable_deletion_protection = var.enable_deletion_protection
  idle_timeout               = var.idle_timeout

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-alb"
  })
}

# Target Group
resource "aws_lb_target_group" "this" {
  for_each = var.target_groups

  name        = "${var.project_name}-${var.environment}-${each.key}-tg"
  port        = each.value.port
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    path                = each.value.health_path
    matcher             = lookup(each.value, "matcher", "200") # 기본값은 200
    protocol            = "HTTP"
    port                = "traffic-port"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-${each.key}-tg"
  })
}
