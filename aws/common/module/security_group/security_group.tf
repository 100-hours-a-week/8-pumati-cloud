# ------------------------------------------------------------
# 프론트엔드 보안 그룹
# ------------------------------------------------------------
resource "aws_security_group" "frontend_sg" {
  name        = "${var.project_name}-${var.environment}-frontend-sg"
  description = "Security group for frontend instance"
  vpc_id      = var.vpc_id

  # SSH 접근 (모든 IP 허용)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access from anywhere"
  }

  # HTTP/HTTPS 접근 (모든 IP 허용)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access from anywhere"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access from anywhere"
  }

  # 모든 아웃바운드 트래픽 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-frontend-sg"
  })
}

# ------------------------------------------------------------
# 백엔드 보안 그룹
# ------------------------------------------------------------
resource "aws_security_group" "backend_sg" {
  name        = "${var.project_name}-${var.environment}-backend-sg"
  description = "Security group for backend instance"
  vpc_id      = var.vpc_id

  # SSH 접근 (모든 IP 허용)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access from anywhere"
  }

  # 백엔드 API 접근 (8080 포트)
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "API access from anywhere"
  }

  # 프론트엔드로부터의 접근
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.frontend_sg.id]
    description     = "All access from frontend"
  }

  # 모든 아웃바운드 트래픽 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-backend-sg"
  })
}

# ------------------------------------------------------------
# Jenkins 보안 그룹
# ------------------------------------------------------------
resource "aws_security_group" "jenkins_sg" {
  name        = "${var.project_name}-${var.environment}-jenkins-sg"
  description = "Security group for Jenkins CI server"
  vpc_id      = var.vpc_id

  # SSH 접근 (모든 IP 허용)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access from anywhere"
  }

  # Jenkins 웹 인터페이스 접근 (GitHub 웹훅 포함)
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # GitHub 웹훅은 Jenkins 웹 인터페이스를 통해 들어옴
    description = "Jenkins web interface and GitHub webhook access"
  }

  # 모든 아웃바운드 트래픽 허용 (ECR 푸시를 위해 필요)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic for ECR push"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-jenkins-sg"
  })
}
