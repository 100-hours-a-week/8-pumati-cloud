# 05-compute/main.tf

#-------------------------------
#  환경 변수 시크릿 구성
#-------------------------------
# 백엔드 환경 변수 설정
resource "aws_secretsmanager_secret" "backend_env" {
  name        = "${local.project_name}-${local.environment}-backend-env"
  description = "Backend .env file contents"
  recovery_window_in_days = 0
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-backend-env"
  })
}

resource "aws_secretsmanager_secret_version" "backend_env" {
  secret_id     = aws_secretsmanager_secret.backend_env.id
  secret_string = var.backend_env_content
}

# 프론트엔드 환경 변수 설정
resource "aws_secretsmanager_secret" "frontend_env" {
  name        = "${local.project_name}-${local.environment}-frontend-env"
  description = "Frontend .env file contents"
  recovery_window_in_days = 0
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-frontend-env"
  })
}

resource "aws_secretsmanager_secret_version" "frontend_env" {
  secret_id     = aws_secretsmanager_secret.frontend_env.id
  secret_string = var.frontend_env_content
}

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

# 프론트엔드 EC2용 보안 그룹
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

  # SSH 액세스 허용
  ingress {
    from_port   = 22
    to_port     = 22
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
    Name = "${local.project_name}-${local.environment}-frontend-sg"
  })
}

# 백엔드 EC2용 보안 그룹
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

  # SSH 액세스 허용
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
# 2. IAM 역할 및 인스턴스 프로필 구성
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

# IAM 정책에 Secrets Manager 접근 권한 추가
resource "aws_iam_policy" "secrets_access" {
  name        = "${local.project_name}-${local.environment}-secrets-access"
  description = "Allow access to Secrets Manager"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Effect   = "Allow",
        Resource = [
          aws_secretsmanager_secret.backend_env.arn,
          aws_secretsmanager_secret.frontend_env.arn,
          data.terraform_remote_state.base.outputs.discord_webhooks_secret_arn
        ]
      }
    ]
  })
}

# 이 정책을 EC2 역할에 연결
resource "aws_iam_role_policy_attachment" "secrets_access_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.secrets_access.arn
}

# CloudWatch 권한 추가
resource "aws_iam_policy" "cloudwatch_policy" {
  name        = "${local.project_name}-${local.environment}-cloudwatch-policy"
  description = "Allow sending logs and metrics to CloudWatch"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "cloudwatch:PutMetricData",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups",
          "logs:CreateLogStream",
          "logs:CreateLogGroup"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

# 이 정책을 EC2 역할에 연결
resource "aws_iam_role_policy_attachment" "cloudwatch_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.cloudwatch_policy.arn
}

# 인스턴스 프로파일
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.project_name}-${local.environment}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

#-------------------------------
# 3. 시작 템플릿 구성
#-------------------------------

# 프론트엔드 시작 템플릿
resource "aws_launch_template" "frontend" {
  name          = "${local.project_name}-${local.environment}-frontend-template"
  image_id      = "ami-0d5bb3742db8fc264"
  instance_type = "t2.medium"
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
    discord_webhook_url = local.discord_webhooks.frontend_webhook,
    frontend_env_secret_name = aws_secretsmanager_secret.frontend_env.name,
    aws_region = local.region
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
  image_id      = "ami-0d5bb3742db8fc264"
  instance_type = "t2.medium"
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
    discord_webhook_url = local.discord_webhooks.backend_webhook,
    backend_env_secret_name = aws_secretsmanager_secret.backend_env.name,
    aws_region = local.region
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
# 4. 대상 그룹 구성
#-------------------------------

# 프론트엔드 대상 그룹
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
# 5. 오토스케일링 그룹 구성
#-------------------------------

# 백엔드 ASG
resource "aws_autoscaling_group" "backend" {
  name                = "${local.project_name}-${local.environment}-backend-asg"
  vpc_zone_identifier = data.terraform_remote_state.network.outputs.public_subnet_ids
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

# 프론트엔드 ASG - 백엔드와 독립적으로 생성
resource "aws_autoscaling_group" "frontend" {
  name                = "${local.project_name}-${local.environment}-frontend-asg"
  vpc_zone_identifier = data.terraform_remote_state.network.outputs.public_subnet_ids
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

#-------------------------------
# 6. ALB 구성
#-------------------------------

# 애플리케이션 로드 밸런서
resource "aws_lb" "main" {
  name               = "${local.project_name}-${local.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  
  # 수정된 서브넷 참조
  subnets            = data.terraform_remote_state.network.outputs.public_subnet_ids

  enable_deletion_protection = false

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-alb"
  })
  
  # 대상 그룹이 모두 생성된 후에 ALB를 생성합니다
  depends_on = [
    aws_lb_target_group.frontend,
    aws_lb_target_group.backend,
    aws_autoscaling_group.frontend,
    aws_autoscaling_group.backend
  ]
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

# HTTPS 리스너 (ACM 인증서 사용)
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:ap-northeast-2:236450698266:certificate/802235a6-034f-43e9-b30b-319566f94059"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# 백엔드 API 경로 리스너 규칙 (HTTP)
resource "aws_lb_listener_rule" "backend_api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    path_pattern {
      values = ["/api/*", "/oauth2/*"]
    }
  }
}

# 백엔드 API 경로 리스너 규칙 (HTTPS)
resource "aws_lb_listener_rule" "backend_api_https" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    path_pattern {
      values = ["/api/*", "/oauth2/*"]
    }
  }
}

#-------------------------------
# 7. Route53 구성
#-------------------------------

# Route53 호스팅 존 데이터 가져오기
data "aws_route53_zone" "this" {
  name = "tebutebu.com"
  private_zone = false
}

# ALB를 가리키는 A 레코드 생성
resource "aws_route53_record" "dev_subdomain" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = local.domain_name # dev.tebutebu.com
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
  
  # ALB가 생성된 후에 Route53 레코드를 생성합니다
  depends_on = [aws_lb.main]
}

