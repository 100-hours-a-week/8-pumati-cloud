# load-test-dev/03-compute/main.tf
# Compute 리소스 구성 - NLB + ALB 조합

# ===============================
# Security Groups
# ===============================

# 백엔드 인스턴스용 보안 그룹
resource "aws_security_group" "backend_instances" {
  name_prefix = "${local.project_name}-${local.environment}-backend-instances-"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  # ALB에서 백엔드 포트 접근
  ingress {
    description     = "Backend app port from ALB"
    from_port       = var.backend_app_port
    to_port         = var.backend_app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_alb.id]
  }

  # SSH 접근 (외부에서 로드테스트용)
  ingress {
    description = "SSH from anywhere (load test only)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 모든 아웃바운드 허용
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name    = "${local.project_name}-${local.environment}-backend-instances-sg"
    Service = "Backend"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# 프론트엔드 인스턴스용 보안 그룹
resource "aws_security_group" "frontend_instances" {
  name_prefix = "${local.project_name}-${local.environment}-frontend-instances-"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  # ALB에서 프론트엔드 포트 접근
  ingress {
    description     = "Frontend app port from ALB"
    from_port       = var.frontend_app_port
    to_port         = var.frontend_app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_alb.id]
  }

  # SSH 접근 (외부에서 로드테스트용)
  ingress {
    description = "SSH from anywhere (load test only)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 모든 아웃바운드 허용
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name    = "${local.project_name}-${local.environment}-frontend-instances-sg"
    Service = "Frontend"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# 백엔드 ALB용 보안 그룹
resource "aws_security_group" "backend_alb" {
  name_prefix = "${local.project_name}-${local.environment}-backend-alb-"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  # NLB에서 HTTP 접근 (NLB 사용시)
  dynamic "ingress" {
    for_each = var.enable_nlb ? [1] : []
    content {
      description = "HTTP from NLB"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = [data.terraform_remote_state.network.outputs.vpc_cidr_block]
    }
  }

  # 직접 HTTP 접근 (NLB 미사용시)
  dynamic "ingress" {
    for_each = var.enable_nlb ? [] : [1]
    content {
      description = "HTTP from internet"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # HTTPS 접근
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name    = "${local.project_name}-${local.environment}-backend-alb-sg"
    Service = "Backend ALB"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# 프론트엔드 ALB용 보안 그룹
resource "aws_security_group" "frontend_alb" {
  name_prefix = "${local.project_name}-${local.environment}-frontend-alb-"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  # NLB에서 HTTP 접근 (NLB 사용시)
  dynamic "ingress" {
    for_each = var.enable_nlb ? [1] : []
    content {
      description = "HTTP from NLB"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = [data.terraform_remote_state.network.outputs.vpc_cidr_block]
    }
  }

  # 직접 HTTP 접근 (NLB 미사용시)
  dynamic "ingress" {
    for_each = var.enable_nlb ? [] : [1]
    content {
      description = "HTTP from internet"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # HTTPS 접근
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name    = "${local.project_name}-${local.environment}-frontend-alb-sg"
    Service = "Frontend ALB"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ===============================
# IAM 역할 생략 (권한 없음)
# ===============================
# IAM 역할 생성 권한이 없으므로 CloudWatch Agent는 
# EC2 인스턴스 메타데이터 기반으로 동작하도록 설정

# ===============================
# CloudWatch Log Groups
# ===============================

# 백엔드 로그 그룹
resource "aws_cloudwatch_log_group" "backend_logs" {
  name              = "/aws/ec2/${local.project_name}-${local.environment}-backend"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = merge(local.common_tags, {
    Name    = "${local.project_name}-${local.environment}-backend-logs"
    Service = "Backend"
  })
}

# 프론트엔드 로그 그룹
resource "aws_cloudwatch_log_group" "frontend_logs" {
  name              = "/aws/ec2/${local.project_name}-${local.environment}-frontend"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = merge(local.common_tags, {
    Name    = "${local.project_name}-${local.environment}-frontend-logs"
    Service = "Frontend"
  })
}

# ===============================
# Launch Templates
# ===============================

# 백엔드 Launch Template
resource "aws_launch_template" "backend" {
  name_prefix   = "${local.project_name}-${local.environment}-backend-"
  image_id      = var.custom_backend_ami
  instance_type = var.instance_type
  key_name      = "8-ktb-chat-keypair"  # SSH 접근용 키페어

  vpc_security_group_ids = [aws_security_group.backend_instances.id]
  
  # IAM 역할 제거 (권한 없음)
  # iam_instance_profile 생략

  monitoring {
    enabled = var.enable_detailed_monitoring
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  # 간단한 User Data (커스텀 AMI 사용)
  user_data = base64encode(templatefile("${path.module}/scripts/backend-setup.sh", {
    project_name    = local.project_name
    environment     = local.environment
    app_port        = var.backend_app_port
    log_group_name  = aws_cloudwatch_log_group.backend_logs.name
    mongodb_uri     = "mongodb://${data.terraform_remote_state.mongodb.outputs.mongodb_private_ip}:27017/loadtest"
  }))

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name    = "backend"  # 단순하고 깔끔한 이름
      Service = "Backend"
      Type    = "Auto Scaling"
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}

# 프론트엔드 Launch Template
resource "aws_launch_template" "frontend" {
  name_prefix   = "${local.project_name}-${local.environment}-frontend-"
  image_id      = var.custom_frontend_ami
  instance_type = var.instance_type
  key_name      = "8-ktb-chat-keypair"  # SSH 접근용 키페어

  vpc_security_group_ids = [aws_security_group.frontend_instances.id]
  
  # IAM 역할 제거 (권한 없음)
  # iam_instance_profile 생략

  monitoring {
    enabled = var.enable_detailed_monitoring
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  # 간단한 User Data (커스텀 AMI 사용)
  user_data = base64encode(templatefile("${path.module}/scripts/frontend-setup.sh", {
    project_name   = local.project_name
    environment    = local.environment
    app_port       = var.frontend_app_port
    log_group_name = aws_cloudwatch_log_group.frontend_logs.name
    backend_api_url = "http://${aws_lb.backend_alb.dns_name}"
  }))

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name    = "frontend"  # 단순하고 깔끔한 이름
      Service = "Frontend"
      Type    = "Auto Scaling"
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ===============================
# Application Load Balancers
# ===============================

# 백엔드 ALB
resource "aws_lb" "backend_alb" {
  name               = "${local.project_name}-${local.environment}-backend-alb"
  internal           = var.enable_nlb  # NLB 사용시 내부 ALB
  load_balancer_type = "application"
  security_groups    = [aws_security_group.backend_alb.id]
  subnets           = var.enable_nlb ? local.private_subnets : local.public_subnets

  enable_deletion_protection = false

  tags = merge(local.common_tags, {
    Name    = "${local.project_name}-${local.environment}-backend-alb"
    Service = "Backend"
  })
}

# 프론트엔드 ALB
resource "aws_lb" "frontend_alb" {
  name               = "${local.project_name}-${local.environment}-frontend-alb"
  internal           = var.enable_nlb  # NLB 사용시 내부 ALB
  load_balancer_type = "application"
  security_groups    = [aws_security_group.frontend_alb.id]
  subnets           = var.enable_nlb ? local.private_subnets : local.public_subnets

  enable_deletion_protection = false

  tags = merge(local.common_tags, {
    Name    = "${local.project_name}-${local.environment}-frontend-alb"
    Service = "Frontend"
  })
}

# ===============================
# Target Groups
# ===============================

# 백엔드 Target Group
resource "aws_lb_target_group" "backend" {
  name     = "${local.project_name}-${local.environment}-backend-tg"
  port     = var.backend_app_port
  protocol = "HTTP"
  vpc_id   = data.terraform_remote_state.network.outputs.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = var.healthy_threshold
    unhealthy_threshold = var.unhealthy_threshold
    timeout             = var.health_check_timeout
    interval            = var.health_check_interval
    path                = var.health_check_path
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  tags = merge(local.common_tags, {
    Name    = "${local.project_name}-${local.environment}-backend-tg"
    Service = "Backend"
  })
}

# 프론트엔드 Target Group
resource "aws_lb_target_group" "frontend" {
  name     = "${local.project_name}-${local.environment}-frontend-tg"
  port     = var.frontend_app_port
  protocol = "HTTP"
  vpc_id   = data.terraform_remote_state.network.outputs.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = var.healthy_threshold
    unhealthy_threshold = var.unhealthy_threshold
    timeout             = var.health_check_timeout
    interval            = var.health_check_interval
    path                = "/"  # 프론트엔드는 루트 경로
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  tags = merge(local.common_tags, {
    Name    = "${local.project_name}-${local.environment}-frontend-tg"
    Service = "Frontend"
  })
}

# ===============================
# ALB Listeners
# ===============================

# 백엔드 ALB 리스너
resource "aws_lb_listener" "backend" {
  load_balancer_arn = aws_lb.backend_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  tags = merge(local.common_tags, {
    Name    = "${local.project_name}-${local.environment}-backend-listener"
    Service = "Backend"
  })
}

# 프론트엔드 ALB 리스너
resource "aws_lb_listener" "frontend" {
  load_balancer_arn = aws_lb.frontend_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }

  tags = merge(local.common_tags, {
    Name    = "${local.project_name}-${local.environment}-frontend-listener"
    Service = "Frontend"
  })
}

# ===============================
# Network Load Balancer (선택적)
# ===============================

# 백엔드 NLB
resource "aws_lb" "backend_nlb" {
  count = var.enable_nlb ? 1 : 0

  name               = "${local.project_name}-${local.environment}-backend-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets           = local.public_subnets

  enable_deletion_protection = false

  tags = merge(local.common_tags, {
    Name    = "${local.project_name}-${local.environment}-backend-nlb"
    Service = "Backend NLB"
  })
}

# 프론트엔드 NLB
resource "aws_lb" "frontend_nlb" {
  count = var.enable_nlb ? 1 : 0

  name               = "${local.project_name}-${local.environment}-frontend-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets           = local.public_subnets

  enable_deletion_protection = false

  tags = merge(local.common_tags, {
    Name    = "${local.project_name}-${local.environment}-frontend-nlb"
    Service = "Frontend NLB"
  })
}

# NLB Target Groups (ALB를 타겟으로)
resource "aws_lb_target_group" "backend_nlb_to_alb" {
  count = var.enable_nlb ? 1 : 0

  name        = "${local.project_name}-${local.environment}-backend-nlb-tg"
  port        = 80
  protocol    = "TCP"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
  target_type = "alb"

  health_check {
    enabled             = true
    healthy_threshold   = var.healthy_threshold
    unhealthy_threshold = var.unhealthy_threshold
    timeout             = var.health_check_timeout
    interval            = var.health_check_interval
    port                = "80"
    protocol            = "TCP"
  }

  tags = merge(local.common_tags, {
    Name    = "${local.project_name}-${local.environment}-backend-nlb-tg"
    Service = "Backend NLB"
  })
}

resource "aws_lb_target_group" "frontend_nlb_to_alb" {
  count = var.enable_nlb ? 1 : 0

  name        = "${local.project_name}-${local.environment}-frontend-nlb-tg"
  port        = 80
  protocol    = "TCP"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
  target_type = "alb"

  health_check {
    enabled             = true
    healthy_threshold   = var.healthy_threshold
    unhealthy_threshold = var.unhealthy_threshold
    timeout             = var.health_check_timeout
    interval            = var.health_check_interval
    port                = "80"
    protocol            = "TCP"
  }

  tags = merge(local.common_tags, {
    Name    = "${local.project_name}-${local.environment}-frontend-nlb-tg"
    Service = "Frontend NLB"
  })
}

# NLB 리스너들
resource "aws_lb_listener" "backend_nlb" {
  count = var.enable_nlb ? 1 : 0

  load_balancer_arn = aws_lb.backend_nlb[0].arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_nlb_to_alb[0].arn
  }

  tags = merge(local.common_tags, {
    Name    = "${local.project_name}-${local.environment}-backend-nlb-listener"
    Service = "Backend NLB"
  })
}

resource "aws_lb_listener" "frontend_nlb" {
  count = var.enable_nlb ? 1 : 0

  load_balancer_arn = aws_lb.frontend_nlb[0].arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_nlb_to_alb[0].arn
  }

  tags = merge(local.common_tags, {
    Name    = "${local.project_name}-${local.environment}-frontend-nlb-listener"
    Service = "Frontend NLB"
  })
}

# NLB to ALB 연결
resource "aws_lb_target_group_attachment" "backend_nlb_to_alb" {
  count = var.enable_nlb ? 1 : 0

  target_group_arn = aws_lb_target_group.backend_nlb_to_alb[0].arn
  target_id        = aws_lb.backend_alb.arn
  port             = 80
}

resource "aws_lb_target_group_attachment" "frontend_nlb_to_alb" {
  count = var.enable_nlb ? 1 : 0

  target_group_arn = aws_lb_target_group.frontend_nlb_to_alb[0].arn
  target_id        = aws_lb.frontend_alb.arn
  port             = 80
}

# ===============================
# Auto Scaling Groups
# ===============================

# 백엔드 ASG
resource "aws_autoscaling_group" "backend" {
  name                = "${local.project_name}-${local.environment}-backend-asg"
  vpc_zone_identifier = local.private_subnets
  target_group_arns   = [aws_lb_target_group.backend.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300

  min_size         = var.backend_asg_min
  max_size         = var.backend_asg_max
  desired_capacity = var.backend_asg_desired

  launch_template {
    id      = aws_launch_template.backend.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "backend"
    propagate_at_launch = true  # 인스턴스에 이름 전파
  }

  dynamic "tag" {
    for_each = local.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  tag {
    key                 = "Service"
    value               = "Backend"
    propagate_at_launch = true
  }
}

# 프론트엔드 ASG
resource "aws_autoscaling_group" "frontend" {
  name                = "${local.project_name}-${local.environment}-frontend-asg"
  vpc_zone_identifier = local.private_subnets
  target_group_arns   = [aws_lb_target_group.frontend.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300

  min_size         = var.frontend_asg_min
  max_size         = var.frontend_asg_max
  desired_capacity = var.frontend_asg_desired

  launch_template {
    id      = aws_launch_template.frontend.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "frontend"
    propagate_at_launch = true  # 인스턴스에 이름 전파
  }

  dynamic "tag" {
    for_each = local.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  tag {
    key                 = "Service"
    value               = "Frontend"
    propagate_at_launch = true
  }
} 