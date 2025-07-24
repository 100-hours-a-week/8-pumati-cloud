# load-test/02-network/main.tf
# 네트워크 인프라 구성 - Load Test 환경 (퍼블릭 서브넷 2개 + S3 엔드포인트만)

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

# 퍼블릭 서브넷 생성 (2개)
resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = ["10.10.1.0/24", "10.10.2.0/24"][count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-public-${substr(data.aws_availability_zones.available.names[count.index], -1, 1)}"
    Type = "public"
    Tier = "Public"
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
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

#-------------------------------
# VPC Endpoints (S3만 유지 - Gateway 타입으로 무료)
#-------------------------------

# S3 VPC Endpoint (Gateway 타입으로 무료)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${local.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.public.id]

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-s3-endpoint"
      Type = "VPC Endpoint"
      Service = "S3"
    }
  )
}