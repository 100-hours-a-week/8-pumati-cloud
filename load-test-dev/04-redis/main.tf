# load-test-dev/04-redis/main.tf
# Redis 마스터-슬레이브 구성 - 부하 테스트 환경

# ===============================
# Redis용 보안 그룹
# ===============================

# Redis 마스터용 보안 그룹
resource "aws_security_group" "redis_master" {
  name_prefix = "${local.project_name}-${local.environment}-redis-master-"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  # Redis 포트 (6379) - VPC 내부에서만 접근 허용
  ingress {
    description = "Redis port from VPC"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [data.terraform_remote_state.network.outputs.vpc_cidr_block]
  }

  # SSH 접근 (관리용)
  ingress {
    description = "SSH for management"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # 부하테스트용으로 외부 접근 허용
  }

  # 모든 아웃바운드 트래픽 허용
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name    = "${local.project_name}-${local.environment}-redis-master-sg"
    Service = "Redis Master"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Redis 슬레이브용 보안 그룹
resource "aws_security_group" "redis_slave" {
  name_prefix = "${local.project_name}-${local.environment}-redis-slave-"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  # Redis 포트 (6379) - VPC 내부에서만 접근 허용
  ingress {
    description = "Redis port from VPC"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [data.terraform_remote_state.network.outputs.vpc_cidr_block]
  }

  # SSH 접근 (관리용)
  ingress {
    description = "SSH for management"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # 부하테스트용으로 외부 접근 허용
  }

  # 모든 아웃바운드 트래픽 허용
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name    = "${local.project_name}-${local.environment}-redis-slave-sg"
    Service = "Redis Slave"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ===============================
# Redis 마스터 인스턴스
# ===============================

resource "aws_instance" "redis_master" {
  ami                    = "ami-0a6f55b9b219e3e66"  # Ubuntu 22.04 LTS
  instance_type          = "t3.small"
  key_name               = "8-ktb-chat-keypair"
  vpc_security_group_ids = [aws_security_group.redis_master.id]
  subnet_id              = data.terraform_remote_state.network.outputs.public_subnet_ids[0]

  # 상세 모니터링 활성화
  monitoring = true

  # Redis 마스터 설치 및 설정 스크립트
  user_data = base64encode(templatefile("${path.module}/scripts/redis-master-setup.sh", {
    project_name = local.project_name
    environment  = local.environment
  }))

  tags = merge(local.common_tags, {
    Name    = "${local.project_name}-${local.environment}-redis-master"
    Service = "Redis Master"
    Type    = "Database"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ===============================
# Redis 슬레이브 인스턴스
# ===============================

resource "aws_instance" "redis_slave" {
  ami                    = "ami-0a6f55b9b219e3e66"  # Ubuntu 22.04 LTS
  instance_type          = "t3.small"
  key_name               = "8-ktb-chat-keypair"
  vpc_security_group_ids = [aws_security_group.redis_slave.id]
  subnet_id              = data.terraform_remote_state.network.outputs.public_subnet_ids[1]

  # 상세 모니터링 활성화
  monitoring = true

  # 마스터 인스턴스가 생성된 후에 슬레이브 생성
  depends_on = [aws_instance.redis_master]

  # Redis 슬레이브 설치 및 설정 스크립트
  user_data = base64encode(templatefile("${path.module}/scripts/redis-slave-setup.sh", {
    project_name  = local.project_name
    environment   = local.environment
    master_ip     = aws_instance.redis_master.private_ip
  }))

  tags = merge(local.common_tags, {
    Name    = "${local.project_name}-${local.environment}-redis-slave"
    Service = "Redis Slave"
    Type    = "Database"
  })

  lifecycle {
    create_before_destroy = true
  }
}
