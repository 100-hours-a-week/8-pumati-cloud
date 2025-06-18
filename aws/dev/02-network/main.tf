# 가용 영역 데이터 소스
data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "zone-name"
    values = ["ap-northeast-2a", "ap-northeast-2c"]
  }
}

# VPC 생성
resource "aws_vpc" "main" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-vpc"
      Type = "VPC"
    }
  )
}

# 인터넷 게이트웨이 생성
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-igw"
      Type = "Internet Gateway"
    }
  )
}

# 퍼블릭 서브넷 생성
resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = ["10.10.1.0/24", "10.10.2.0/24"][count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-public-${substr(data.aws_availability_zones.available.names[count.index], -1, 1)}"
    Type = "public"
    
    # 🔧 EKS ALB Controller용 태그 추가
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/${local.project_name}-${local.environment}-eks-cluster" = "shared"
  })
}

# 프라이빗 서브넷 생성
resource "aws_subnet" "private" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = ["10.10.11.0/24", "10.10.12.0/24"][count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-private-${substr(data.aws_availability_zones.available.names[count.index], -1, 1)}"
    Type = "private"
    
    # 🔧 EKS 내부 ALB Controller용 태그 추가
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/${local.project_name}-${local.environment}-eks-cluster" = "shared"
    
    # ✅ Karpenter 디스커버리 태그 추가
    "karpenter.sh/discovery" = "${local.project_name}-${local.environment}-eks-cluster"
  })
}

# DB 서브넷 생성
resource "aws_subnet" "db" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = ["10.10.21.0/24", "10.10.22.0/24"][count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-db-subnet-${substr(data.aws_availability_zones.available.names[count.index], -1, 1)}"
      Type = "DB Subnet"
      Tier = "Database"
    }
  )
}

#-------------------------------
# NAT Gateway (비활성화됨 - 비용 절약을 위해 NAT 인스턴스로 교체)
#-------------------------------

# Elastic IP for NAT Gateway (단일 NAT) - 비활성화
# resource "aws_eip" "nat" {
#   domain     = "vpc"
#   depends_on = [aws_internet_gateway.main]
# 
#   tags = merge(
#     local.common_tags,
#     {
#       Name = "${local.project_name}-${local.environment}-nat-eip"
#       Type = "NAT Gateway EIP"
#     }
#   )
# }

# NAT 게이트웨이 생성 (단일 NAT - 비용 절약) - 비활성화
# resource "aws_nat_gateway" "main" {
#   allocation_id = aws_eip.nat.id
#   subnet_id     = aws_subnet.public[0].id
#   depends_on    = [aws_internet_gateway.main]
# 
#   tags = merge(
#     local.common_tags,
#     {
#       Name = "${local.project_name}-${local.environment}-nat-gw"
#       Type = "NAT Gateway"
#     }
#   )
# }

# 퍼블릭 라우팅 테이블
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-public-rt"
      Type = "Public Route Table"
    }
  )
}

# 프라이빗 라우팅 테이블 (NAT 인스턴스 사용)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  # route {
  #   cidr_block     = "0.0.0.0/0"
  #   nat_gateway_id = aws_nat_gateway.main.id
  # }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-private-rt"
      Type = "Private Route Table"
    }
  )
}

# DB 라우팅 테이블 (NAT Gateway를 통한 인터넷 접근 허용)
resource "aws_route_table" "db" {
  vpc_id = aws_vpc.main.id

  # # NAT Gateway를 통한 인터넷 접근 경로 추가
  # route {
  #   cidr_block     = "0.0.0.0/0"
  #   nat_gateway_id = aws_nat_gateway.main.id
  # }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-db-rt"
      Type = "DB Route Table"
    }
  )
}

# 퍼블릭 서브넷 라우팅 테이블 연결
resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# 프라이빗 서브넷 라우팅 테이블 연결
resource "aws_route_table_association" "private" {
  count = 2

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# DB 서브넷 라우팅 테이블 연결
resource "aws_route_table_association" "db" {
  count = 2

  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.db.id
}

# DB 서브넷 그룹 (RDS용)
resource "aws_db_subnet_group" "main" {
  name       = "${local.project_name}-${local.environment}-db-subnet-group"
  subnet_ids = aws_subnet.db[*].id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-db-subnet-group"
      Type = "DB Subnet Group"
    }
  )
}

#-------------------------------
# VPC Endpoints (S3만 유지 - 무료!)
#-------------------------------

# S3 VPC Endpoint (로깅, 백업용 - Gateway 타입으로 무료)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${local.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id, aws_route_table.db.id]

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-s3-endpoint"
      Type = "VPC Endpoint"
    }
  )
}

# 다른 모든 Interface 엔드포인트들 제거됨!
# - ECR API, ECR DKR, EKS, Secrets Manager, CloudWatch Logs
# - SSM, SSM Messages, EC2 Messages
# → NAT Gateway를 통해 인터넷으로 접근하므로 문제없음!

#-------------------------------
# NAT 인스턴스 (비용 절약용)
#-------------------------------

# NAT 인스턴스용 보안 그룹
resource "aws_security_group" "nat_instance" {
  name_prefix = "${local.project_name}-${local.environment}-nat-instance-"
  vpc_id      = aws_vpc.main.id

  # HTTP 트래픽 허용 (프라이빗 서브넷에서)
  ingress {
    description = "HTTP from Private Subnets"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.10.11.0/24", "10.10.12.0/24", "10.10.21.0/24", "10.10.22.0/24"]
  }

  # HTTPS 트래픽 허용 (프라이빗 서브넷에서)
  ingress {
    description = "HTTPS from Private Subnets"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.10.11.0/24", "10.10.12.0/24", "10.10.21.0/24", "10.10.22.0/24"]
  }

  # SSH 접근 허용 (관리용)
  ingress {
    description = "SSH for management"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.10.0.0/16"] # VPC 내부에서만 SSH 허용
  }

  # 모든 아웃바운드 트래픽 허용
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
      Name = "${local.project_name}-${local.environment}-nat-instance-sg"
      Type = "Security Group"
      Purpose = "NAT Instance"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# NAT 인스턴스용 최신 Amazon Linux 2 AMI 조회
data "aws_ami" "amazon_linux_nat" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-vpc-nat-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# NAT 인스턴스용 IAM 역할 (CloudWatch 로그 전송 등을 위해)
resource "aws_iam_role" "nat_instance" {
  name = "${local.project_name}-${local.environment}-nat-instance-role"

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

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-nat-instance-role"
      Type = "IAM Role"
    }
  )
}

# NAT 인스턴스용 IAM 정책 연결 (기본 EC2 권한)
resource "aws_iam_role_policy_attachment" "nat_instance_ssm" {
  role       = aws_iam_role.nat_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# NAT 인스턴스용 인스턴스 프로파일
resource "aws_iam_instance_profile" "nat_instance" {
  name = "${local.project_name}-${local.environment}-nat-instance-profile"
  role = aws_iam_role.nat_instance.name

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-nat-instance-profile"
      Type = "Instance Profile"
    }
  )
}

# NAT 인스턴스 생성
resource "aws_instance" "nat_instance" {
  ami                    = data.aws_ami.amazon_linux_nat.id
  instance_type          = "t2.micro"
  key_name               = "pumati-full-master" # 키페어가 있다고 가정
  subnet_id              = aws_subnet.public[0].id # 첫 번째 퍼블릭 서브넷에 배치
  vpc_security_group_ids = [aws_security_group.nat_instance.id]
  iam_instance_profile   = aws_iam_instance_profile.nat_instance.name

  # Source/Destination 체크 비활성화 (NAT 기능을 위해 필수!)
  source_dest_check = false

  # 인스턴스 모니터링 활성화
  monitoring = true

  # 사용자 데이터 스크립트 (NAT 기능 설정)
  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    
    # IP 포워딩 활성화
    echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
    sysctl -p
    
    # iptables NAT 규칙 설정
    iptables -t nat -A POSTROUTING -o eth0 -s 10.10.0.0/16 -j MASQUERADE
    
    # iptables 규칙 영구 저장
    service iptables save
    
    # CloudWatch 에이전트 설치 (모니터링용)
    yum install -y amazon-cloudwatch-agent
    
    # 로그 설정
    echo "NAT Instance started at $(date)" >> /var/log/nat-instance.log
  EOF
  )

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-nat-instance"
      Type = "NAT Instance"
      Purpose = "Cost-effective NAT solution"
      InstanceType = "t2.micro"
    }
  )

  # 생명주기 설정 - 인스턴스 교체 시 새 인스턴스 먼저 생성
  lifecycle {
    create_before_destroy = true
  }
}

# NAT 인스턴스용 Elastic IP 할당
resource "aws_eip" "nat_instance" {
  instance = aws_instance.nat_instance.id
  domain   = "vpc"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-nat-instance-eip"
      Type = "Elastic IP"
      Purpose = "NAT Instance"
    }
  )

  # 인터넷 게이트웨이 의존성
  depends_on = [aws_internet_gateway.main]
}

# NAT 인스턴스로의 라우트 (별도 리소스)
resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat_instance.primary_network_interface_id
}

resource "aws_route" "db_nat" {
  route_table_id         = aws_route_table.db.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat_instance.primary_network_interface_id
}