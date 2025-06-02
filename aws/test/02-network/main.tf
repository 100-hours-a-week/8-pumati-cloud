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

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-public-subnet-${substr(data.aws_availability_zones.available.names[count.index], -1, 1)}"
      Type = "Public Subnet"
      Tier = "Public"
    }
  )
}

# 프라이빗 서브넷 생성
resource "aws_subnet" "private" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = ["10.10.11.0/24", "10.10.12.0/24"][count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-private-subnet-${substr(data.aws_availability_zones.available.names[count.index], -1, 1)}"
      Type = "Private Subnet"
      Tier = "Private"
    }
  )
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

# Elastic IP for NAT Gateway (단일 NAT)
resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-nat-eip"
      Type = "NAT Gateway EIP"
    }
  )
}

# NAT 게이트웨이 생성 (단일 NAT - 비용 절약)
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  depends_on    = [aws_internet_gateway.main]

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-nat-gw"
      Type = "NAT Gateway"
    }
  )
}

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

# 프라이빗 라우팅 테이블 (단일 NAT 사용)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-private-rt"
      Type = "Private Route Table"
    }
  )
}

# DB 라우팅 테이블 (인터넷 접근 없음)
resource "aws_route_table" "db" {
  vpc_id = aws_vpc.main.id

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
# VPC Endpoints (비용 및 성능 최적화)
#-------------------------------

# VPC Endpoints용 보안 그룹
resource "aws_security_group" "vpc_endpoints" {
  name        = "${local.project_name}-${local.environment}-vpc-endpoints-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.main.id

  # HTTPS 접근 (VPC 내부에서만)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
    description = "HTTPS access from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-vpc-endpoints-sg"
      Type = "VPC Endpoints Security Group"
    }
  )
}

# ECR API VPC Endpoint (컨테이너 이미지 다운로드)
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${local.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-ecr-api-endpoint"
      Type = "VPC Endpoint"
    }
  )
}

# ECR DKR VPC Endpoint (컨테이너 이미지 다운로드)
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${local.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-ecr-dkr-endpoint"
      Type = "VPC Endpoint"
    }
  )
}

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

# EKS VPC Endpoint (EKS API 호출)
resource "aws_vpc_endpoint" "eks" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${local.region}.eks"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-eks-endpoint"
      Type = "VPC Endpoint"
    }
  )
}

# Secrets Manager VPC Endpoint (시크릿 조회)
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${local.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-secretsmanager-endpoint"
      Type = "VPC Endpoint"
    }
  )
}

# CloudWatch Logs VPC Endpoint (로깅)
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${local.region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-logs-endpoint"
      Type = "VPC Endpoint"
    }
  )
}
