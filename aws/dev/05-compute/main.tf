# 03-compute/main.tf

# 네트워크 정보 가져오기


#-------------------------------
# 1. 보안 그룹 구성
#-------------------------------

# ALB용 보안 그룹 (HTTP/HTTPS 허용)
resource "aws_security_group" "alb_sg" {
  name        = "${local.project_name}-${local.environment}-alb-sg"
  description = "Allow HTTP and HTTPS"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-alb-sg"
  })
}

# 프론트엔드 EC2용 보안 그룹 (SSH 포트 추가)
resource "aws_security_group" "frontend_sg" {
  name        = "${local.project_name}-${local.environment}-frontend-sg"
  description = "Allow traffic from ALB"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # SSH 액세스 허용 (추가)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # 또는 제한된 IP 범위 사용 권장
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-frontend-sg"
  })
}

# 백엔드 EC2용 보안 그룹 (SSH 포트 추가)
resource "aws_security_group" "backend_sg" {
  name        = "${local.project_name}-${local.environment}-backend-sg"
  description = "Allow traffic from ALB"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # SSH 액세스 허용 (추가)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # 또는 제한된 IP 범위 사용 권장
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-backend-sg"
  })
}

#-------------------------------
# 2. 시작 템플릿 구성
#-------------------------------

# 시크릿 매니저에 접근할 수 있는 IAM 역할
resource "aws_iam_role" "ec2_role" {
  name = "${local.project_name}-${local.environment}-ec2-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  
  tags = local.common_tags
}

# 시크릿 매니저 접근 정책
resource "aws_iam_policy" "secrets_access" {
  name        = "${local.project_name}-${local.environment}-secrets-access"
  description = "Allow access to specific secrets"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
        ]
        Effect = "Allow"
        Resource = [
          data.terraform_remote_state.base.outputs.discord_webhooks_secret_arn
        ]
      }
    ]
  })
}

# 역할에 정책 연결
resource "aws_iam_role_policy_attachment" "secrets_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.secrets_access.arn
}

# 인스턴스 프로파일
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.project_name}-${local.environment}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# base 모듈 상태 참조
data "terraform_remote_state" "base" {
  backend = "s3"
  config = {
    bucket = "s3-terraform-pumati"
    key    = "aws/dev/base/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# 프론트엔드 시작 템플릿
resource "aws_launch_template" "frontend" {
  name          = "${local.project_name}-${local.environment}-frontend-template"
  image_id      = "ami-05377cf8cfef186c2"
  instance_type = "t2.small"
  key_name      = "pumati-full-master"

  # 스팟 인스턴스 요청 설정
  instance_market_options {
    market_type = "spot"
  }

  vpc_security_group_ids = [aws_security_group.frontend_sg.id]

  # IAM 인스턴스 프로파일 추가
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  user_data = base64encode(templatefile("${path.module}/startup-script/frontend-startup.sh", {
    project_name = local.project_name,
    environment = local.environment,
    discord_webhook_url = local.discord_webhooks.frontend_webhook
  }))

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${local.project_name}-${local.environment}-frontend"
    })
  }

  monitoring {
    enabled = true
  }
}

# 백엔드 시작 템플릿
resource "aws_launch_template" "backend" {
  name          = "${local.project_name}-${local.environment}-backend-template"
  image_id      = "ami-05377cf8cfef186c2"
  instance_type = "t2.small"
  key_name      = "pumati-full-master"

  # 스팟 인스턴스 요청 설정
  instance_market_options {
    market_type = "spot"
  }

  vpc_security_group_ids = [aws_security_group.backend_sg.id]

  # IAM 인스턴스 프로파일 추가
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  user_data = base64encode(templatefile("${path.module}/startup-script/backend-startup.sh", {
    project_name = local.project_name,
    environment = local.environment,
    discord_webhook_url = local.discord_webhooks.backend_webhook
  }))

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${local.project_name}-${local.environment}-backend"
    })
  }

  monitoring {
    enabled = true
  }
}

#-------------------------------
# 3. 대상 그룹 구성
#-------------------------------

# 프론트엔드 대상 그룹 - 로드 밸런서가 트래픽을 보낼 대상 서버들의 그룹 정의
resource "aws_lb_target_group" "frontend" {
  name     = "${local.project_name}-${local.environment}-frontend-tg"  # 대상 그룹 이름 (예: pumati-dev-frontend-tg)
  port     = 80                # 대상 그룹이 트래픽을 수신할 포트 (HTTP 기본 포트)
  protocol = "HTTP"            # 사용할 프로토콜 (HTTP)
  vpc_id   = data.terraform_remote_state.network.outputs.vpc_id  # 이 대상 그룹이 속할 VPC의 ID (네트워크 모듈에서 가져옴)

  # 헬스 체크 설정 - 대상 그룹의 인스턴스 상태를 주기적으로 확인하는 설정
  health_check {
    enabled             = true              # 헬스 체크 활성화 여부
    path                = "/"               # 상태 확인 요청을 보낼 경로 (루트 경로)
    port                = "traffic-port"    # 헬스 체크 요청을 보낼 포트 (트래픽 포트와 동일)
    healthy_threshold   = 2                 # 정상으로 간주하기 위한 연속 성공 횟수 (2회 연속 성공하면 정상)
    unhealthy_threshold = 5                 # 비정상으로 간주하기 위한 연속 실패 횟수 (5회 연속 실패해야 비정상)
    timeout             = 10                # 응답 대기 시간(초) - 10초 이내 응답이 오지 않으면 실패로 간주
    interval            = 30                # 헬스 체크 요청 간격(초) - 60초마다 상태 확인
    matcher             = "200,302,404"     # 정상으로 간주할 HTTP 상태 코드들 (200, 302, 404 응답이면 정상으로 간주)
  }

  # 태그 설정 - 리소스 식별 및 관리를 위한 메타데이터
  tags = merge(local.common_tags, {         # 공통 태그와 Name 태그 병합
    Name = "${local.project_name}-${local.environment}-frontend-tg"  # 리소스 이름 태그
  })
}

# 백엔드 대상 그룹
resource "aws_lb_target_group" "backend" {
  name     = "${local.project_name}-${local.environment}-backend-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.terraform_remote_state.network.outputs.vpc_id

  health_check {
    enabled             = true
    path                = "/api"    # 추후 백엔드 헬스체크 로직 추가
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 10
    interval            = 30
    matcher             = "200,302,404"
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-backend-tg"
  })
}

#-------------------------------
# 4. ALB 구성
#-------------------------------

# 애플리케이션 로드 밸런서
resource "aws_lb" "main" {
  name               = "${local.project_name}-${local.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [data.terraform_remote_state.network.outputs.subnet_id]

  enable_deletion_protection = false

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-alb"
  })
}

# 기본 리스너 (HTTP)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# 백엔드 API 경로 리스너 규칙
resource "aws_lb_listener_rule" "backend_api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

#-------------------------------
# 5. 오토스케일링 그룹 구성
#-------------------------------

# 프론트엔드 ASG
resource "aws_autoscaling_group" "frontend" {
  name                = "${local.project_name}-${local.environment}-frontend-asg"
  vpc_zone_identifier = [data.terraform_remote_state.network.outputs.subnet_id]
  desired_capacity    = 1
  min_size            = 1
  max_size            = 3

  launch_template {
    id      = aws_launch_template.frontend.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.frontend.arn]

  health_check_type         = "EC2"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "${local.project_name}-${local.environment}-frontend"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = local.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# 백엔드 ASG
resource "aws_autoscaling_group" "backend" {
  name                = "${local.project_name}-${local.environment}-backend-asg"
  vpc_zone_identifier = [data.terraform_remote_state.network.outputs.subnet_id]
  desired_capacity    = 1
  min_size            = 1
  max_size            = 3

  launch_template {
    id      = aws_launch_template.backend.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.backend.arn]

  health_check_type         = "EC2"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "${local.project_name}-${local.environment}-backend"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = local.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

#-------------------------------
# 6. 오토스케일링 정책 구성 (옵션)
#-------------------------------

# # CPU 기반 스케일 아웃 정책 (프론트엔드)
# resource "aws_autoscaling_policy" "frontend_scale_out" {
#   name                   = "${local.project_name}-${local.environment}-frontend-scale-out"
#   scaling_adjustment     = 1
#   adjustment_type        = "ChangeInCapacity"
#   cooldown               = 300
#   autoscaling_group_name = aws_autoscaling_group.frontend.name
# }

# # CPU 기반 스케일 인 정책 (프론트엔드)
# resource "aws_autoscaling_policy" "frontend_scale_in" {
#   name                   = "${local.project_name}-${local.environment}-frontend-scale-in"
#   scaling_adjustment     = -1
#   adjustment_type        = "ChangeInCapacity"
#   cooldown               = 300
#   autoscaling_group_name = aws_autoscaling_group.frontend.name
# }

# # CPU 기반 스케일 아웃 정책 (백엔드)
# resource "aws_autoscaling_policy" "backend_scale_out" {
#   name                   = "${local.project_name}-${local.environment}-backend-scale-out"
#   scaling_adjustment     = 1
#   adjustment_type        = "ChangeInCapacity"
#   cooldown               = 300
#   autoscaling_group_name = aws_autoscaling_group.backend.name
# }

# # CPU 기반 스케일 인 정책 (백엔드)
# resource "aws_autoscaling_policy" "backend_scale_in" {
#   name                   = "${local.project_name}-${local.environment}-backend-scale-in"
#   scaling_adjustment     = -1
#   adjustment_type        = "ChangeInCapacity"
#   cooldown               = 300
#   autoscaling_group_name = aws_autoscaling_group.backend.name
# }
