# shared vpc 생성
# 단일 가용 영역, 단일 퍼블릭 서브넷
# prod vpc와의 피어링 연결

# VPC 생성
resource "aws_vpc" "main" {
  cidr_block           = "10.9.0.0/16"
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
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.9.1.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true 

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-public-ap-northeast-2a"
    Type = "public"
  })
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

# 퍼블릭 서브넷 라우팅 테이블 연결
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# VPC 피어링 연결 생성
resource "aws_vpc_peering_connection" "shared_to_prod" {
  # 현재 VPC (shared)
  vpc_id = aws_vpc.main.id
  
  # 연결할 VPC (prod)
  peer_vpc_id = "vpc-059353dacd9e67556"
  
  # 같은 리전, 같은 계정이므로 auto_accept 활성화
  auto_accept = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-to-prod-peering"
      Side = "Requester"
      Type = "VPC Peering Connection"
    }
  )
}

# shared VPC에서 prod VPC로의 라우트 추가
resource "aws_route" "shared_to_prod" {
  route_table_id            = aws_route_table.public.id
  destination_cidr_block    = "10.3.0.0/16"  # prod VPC CIDR
  vpc_peering_connection_id = aws_vpc_peering_connection.shared_to_prod.id

  depends_on = [aws_vpc_peering_connection.shared_to_prod]
}

# prod VPC의 라우팅 테이블에 shared VPC로의 라우트 추가
# prod VPC의 라우팅 테이블 ID를 가져오기 위한 data source
data "aws_vpc" "prod" {
  id = "vpc-059353dacd9e67556"
}

# prod VPC의 퍼블릭 라우팅 테이블 찾기
data "aws_route_tables" "prod_public" {
  vpc_id = data.aws_vpc.prod.id
  
  filter {
    name   = "tag:Type"
    values = ["Public Route Table"]
  }
}

# prod VPC의 각 라우팅 테이블에 shared VPC로의 라우트 추가
resource "aws_route" "prod_to_shared" {
  count = length(data.aws_route_tables.prod_public.ids)
  
  route_table_id            = data.aws_route_tables.prod_public.ids[count.index]
  destination_cidr_block    = "10.9.0.0/16"  # shared VPC CIDR
  vpc_peering_connection_id = aws_vpc_peering_connection.shared_to_prod.id

  depends_on = [aws_vpc_peering_connection.shared_to_prod]
}

# 보안 그룹 규칙 (선택사항) - shared VPC에서 prod VPC로의 통신 허용
resource "aws_security_group" "shared_vpc_peering" {
  name        = "${local.project_name}-${local.environment}-vpc-peering-sg"
  description = "Security group for VPC peering communication"
  vpc_id      = aws_vpc.main.id

  # prod VPC에서 오는 트래픽 허용
  ingress {
    description = "Allow all traffic from prod VPC"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.3.0.0/16"]  # prod VPC CIDR
  }

  # shared VPC에서 prod VPC로 나가는 트래픽 허용
  egress {
    description = "Allow all traffic to prod VPC"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.3.0.0/16"]  # prod VPC CIDR
  }

  # ICMP 핑 허용 (네트워크 연결 테스트용)
  ingress {
    description = "Allow ICMP from prod VPC"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.3.0.0/16"]
  }

  egress {
    description = "Allow ICMP to prod VPC"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.3.0.0/16"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-vpc-peering-sg"
      Type = "Security Group"
      Purpose = "VPC Peering"
    }
  )
}
