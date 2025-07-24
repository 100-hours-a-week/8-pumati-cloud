# load-test-dev/02-mongoDB/main.tf
# MongoDB 단일 인스턴스 구성 - Load Test 환경

# MongoDB용 보안 그룹 생성
resource "aws_security_group" "mongodb" {
  name_prefix = "${local.project_name}-${local.environment}-mongodb-"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  # MongoDB 포트 (27017) - VPC 내부에서만 접근 허용
  ingress {
    description = "MongoDB port from VPC"
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = [data.terraform_remote_state.network.outputs.vpc_cidr_block]
  }

  # SSH 접근 (관리용) - VPC 내부에서만 허용
  ingress {
    description = "SSH for management from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [data.terraform_remote_state.network.outputs.vpc_cidr_block]
  }

  # SSH 접근 (외부에서) - 로드테스트용 임시 허용
  ingress {
    description = "SSH for management from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 모든 아웃바운드 트래픽 허용 (패키지 설치, 업데이트 등)
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.project_name}-${local.environment}-mongodb-sg"
      Type    = "Security Group"
      Service = "MongoDB"
      Purpose = "Load Test Database"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# MongoDB 인스턴스 생성
resource "aws_instance" "mongodb" {
  ami           = "ami-08943a151bd468f4e"  # Ubuntu Linux
  instance_type = "t3.small"
  key_name      = "8-ktb-chat-keypair"  # 지정된 키페어 사용
  
  # 첫 번째 퍼블릭 서브넷에 배치 (load-test에서는 퍼블릭 서브넷만 사용)
  subnet_id                   = data.terraform_remote_state.network.outputs.public_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.mongodb.id]
  associate_public_ip_address = true

  # 인스턴스 모니터링 활성화
  monitoring = true

  # 루트 볼륨 설정 (MongoDB 데이터용)
  root_block_device {
    volume_type = "gp3"
    volume_size = 20 # 20GB - 로드테스트용으로 충분
    encrypted   = true
    
    tags = merge(
      local.common_tags,
      {
        Name    = "${local.project_name}-${local.environment}-mongodb-root-volume"
        Type    = "EBS Volume"
        Service = "MongoDB"
      }
    )
  }

  # MongoDB 설치 및 설정 스크립트
  user_data = base64encode(templatefile("${path.module}/scripts/mongodb-install.sh", {
    project_name = local.project_name
    environment  = local.environment
  }))

  tags = merge(
    local.common_tags,
    {
      Name         = "${local.project_name}-${local.environment}-mongodb"
      Type         = "EC2 Instance"
      Service      = "MongoDB"
      Purpose      = "Load Test Database"
      InstanceType = "t3.small"
      OS          = "Ubuntu Linux"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# MongoDB 인스턴스용 Elastic IP
resource "aws_eip" "mongodb" {
  instance = aws_instance.mongodb.id
  domain   = "vpc"

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.project_name}-${local.environment}-mongodb-eip"
      Type    = "Elastic IP"
      Service = "MongoDB"
      Purpose = "Load Test Database"
    }
  )

  depends_on = [data.terraform_remote_state.network]
} 