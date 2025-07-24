# load-test-dev/03-compute/main.tf
# Compute 리소스 구성 - 백엔드 전용 (프론트엔드는 S3로 이전)

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

# 백엔드 ALB용 보안 그룹
resource "aws_security_group" "backend_alb" {
  name_prefix = "${local.project_name}-${local.environment}-backend-alb-"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  # 인터넷에서 HTTP 접근
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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

# ===============================
# Launch Template
# ===============================

# 백엔드 Launch Template
resource "aws_launch_template" "backend" {
  name_prefix   = "${local.project_name}-${local.environment}-backend-"
  image_id      = var.custom_backend_ami
  instance_type = var.instance_type
  key_name      = "8-ktb-chat-keypair"  # SSH 접근용 키페어

  vpc_security_group_ids = [aws_security_group.backend_instances.id]
  
  # 기존 IAM Instance Profile 사용 (유저 권한 활용)
  dynamic "iam_instance_profile" {
    for_each = var.iam_instance_profile_name != "" ? [1] : []
    content {
      name = var.iam_instance_profile_name
    }
  }

  monitoring {
    enabled = var.enable_detailed_monitoring
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  # User Data 스크립트 (커스텀 AMI 사용)
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
      Service = "Backend"
      Type    = "Fixed Instances with Auto Healing"
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ===============================
# Application Load Balancer
# ===============================

# 백엔드 ALB
resource "aws_lb" "backend_alb" {
  name               = "${local.project_name}-${local.environment}-backend-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.backend_alb.id]
  subnets           = local.public_subnets

  enable_deletion_protection = false

  tags = merge(local.common_tags, {
    Name    = "${local.project_name}-${local.environment}-backend-alb"
    Service = "Backend"
  })
}

# ===============================
# Target Group
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

  # Listener가 먼저 삭제되도록 의존성 설정
  lifecycle {
    create_before_destroy = true
  }
}

# ===============================
# ALB Listener
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

# ===============================
# Auto Scaling Group (오토 힐링 전용)
# ===============================

# 백엔드 ASG - 오토 힐링만 활용 (스케일링 없음)
resource "aws_autoscaling_group" "backend" {
  name                = "${local.project_name}-${local.environment}-backend-asg"
  vpc_zone_identifier = local.public_subnets
  target_group_arns   = [aws_lb_target_group.backend.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 60    # 1분 그레이스 피리어드 (빠른 교체)

  # 오토 힐링 전용 설정 (스케일링 없음)
  min_size         = var.backend_instance_count  # 고정 인스턴스 수
  max_size         = var.backend_instance_count  # 최대 인스턴스 수 고정
  desired_capacity = var.backend_instance_count  # 원하는 용량 고정

  # 스케일링 방지 설정
  default_cooldown          = 0    # 쿨다운 없음 (즉시 교체)
  termination_policies      = ["OldestInstance"]
  protect_from_scale_in     = false  # 삭제 시 문제 방지

  launch_template {
    id      = aws_launch_template.backend.id
    version = "$Latest"
  }

  # 인스턴스 이름 태그 설정
  tag {
    key                 = "Name"
    value               = "${local.project_name}-${local.environment}-backend"
    propagate_at_launch = true
  }

  # 공통 태그 적용
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

  tag {
    key                 = "Type"
    value               = "AutoHealing"
    propagate_at_launch = true
  }

  # 인스턴스 교체 시 빠른 업데이트 (무중단 서비스 불필요)
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 0   # 모든 인스턴스 한번에 교체 가능
      instance_warmup       = 30  # 30초 워밍업으로 최소화
      checkpoint_percentages = [100] # 100% 완료 체크포인트만
      checkpoint_delay      = 0   # 체크포인트 대기 시간 없음
    }
    triggers = ["tag", "desired_capacity", "launch_template"] # 모든 변경에 즉시 반응
  }

  # Terraform destroy 시 강제 삭제 설정
  force_delete         = true  # 인스턴스가 있어도 강제 삭제
  wait_for_capacity_timeout = "0"  # 용량 대기 시간 없음

  lifecycle {
    create_before_destroy = false  # 삭제 시 새로 만들지 않음
  }
} 