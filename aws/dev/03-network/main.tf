#-------------------------------
# 1. VPC + Subnet + IGW 구성
#-------------------------------

resource "aws_vpc" "main" {
  # vpc 는 name 속성이 없음. 대신 tags 속성을 사용해야 함.
  cidr_block           = "10.1.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-vpc"
  })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-igw"
  })
}

# 퍼블릭 서브넷 A
resource "aws_subnet" "public_subnet_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.1.0.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-public-subnet-a"
  })
}

# 퍼블릭 서브넷 C
resource "aws_subnet" "public_subnet_c" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = "ap-northeast-2c"
  map_public_ip_on_launch = true
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-public-subnet-c"
  })
}

# 퍼블릭 라우팅 테이블
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-public-rt"
  })
}

# 서브넷 A의 라우팅 테이블 연결
resource "aws_route_table_association" "public_subnet_a_assoc" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}

# 서브넷 C의 라우팅 테이블 연결
resource "aws_route_table_association" "public_subnet_c_assoc" {
  subnet_id      = aws_subnet.public_subnet_c.id
  route_table_id = aws_route_table.public_rt.id
}
