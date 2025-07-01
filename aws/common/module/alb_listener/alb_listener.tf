# HTTPS 리스너 - 기본은 404 반환
resource "aws_lb_listener" "https" {
  count             = var.enable_https ? 1 : 0
  load_balancer_arn = var.load_balancer_arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-${var.service_name}-listener-443"
  })
}

# HTTP → HTTPS 리디렉션 리스너
resource "aws_lb_listener" "http_redirect" {
  count             = var.enable_redirect ? 1 : 0
  load_balancer_arn = var.load_balancer_arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-${var.service_name}-listener-80"
  })
}

# [1] 백엔드로 라우팅
resource "aws_lb_listener_rule" "backend" {
  count        = var.enable_https ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 10

  condition {
    host_header {
      values = var.host_header
    }
  }

  condition {
    path_pattern {
      values = var.backend_path_patterns
    }
  }

  action {
    type             = "forward"
    target_group_arn = var.backend_target_group_arn
  }
}

# [2] 프론트엔드로 라우팅
resource "aws_lb_listener_rule" "frontend" {
  count        = var.enable_https ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 20

  condition {
    host_header {
      values = var.host_header
    }
  }

  condition {
    path_pattern {  
      values = var.frontend_path_patterns
    }
  }

  action {
    type             = "forward"
    target_group_arn = var.frontend_target_group_arn
  }
}
