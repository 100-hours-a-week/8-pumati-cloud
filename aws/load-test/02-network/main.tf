# 가용 영역 데이터 소스
data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "zone-name"
    values = ["ap-northeast-2a", "ap-northeast-2c"]
  }
}

# VPC 생성 - 부하 테스트용 단순화된 네트워크
resource "aws_vpc" "main" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-vpc"
      Type = "VPC"
      Purpose = "Load Test Environment"
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

# 퍼블릭 서브넷 생성 (EKS, DB 모두 여기에 배치)
resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = ["10.10.1.0/24", "10.10.2.0/24"][count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-public-${substr(data.aws_availability_zones.available.names[count.index], -1, 1)}"
    Type = "public"
    Purpose = "Load Test - All Resources"
    
    # EKS ALB Controller용 태그 (외부 ALB)
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/${local.project_name}-${local.environment}-eks-cluster" = "shared"
    
    # EKS 내부 ALB Controller용 태그 (내부 ALB도 퍼블릭에서)
    "kubernetes.io/role/internal-elb" = "1"
    
    # Karpenter 디스커버리 태그
    "karpenter.sh/discovery" = "${local.project_name}-${local.environment}-eks-cluster"
  })
}

# 퍼블릭 라우팅 테이블 (모든 서브넷에서 사용)
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
      Purpose = "Load Test - All Traffic"
    }
  )
}

# 퍼블릭 서브넷 라우팅 테이블 연결
resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# DB 서브넷 그룹 (RDS용) - 퍼블릭 서브넷 사용
resource "aws_db_subnet_group" "main" {
  name       = "${local.project_name}-${local.environment}-db-subnet-group"
  subnet_ids = aws_subnet.public[*].id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-db-subnet-group"
      Type = "DB Subnet Group"
      Purpose = "Load Test DB - Public Access"
    }
  )
}

# S3 VPC Endpoint (선택사항 - 부하 테스트에서는 굳이 필요없지만 유지)
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
      Purpose = "S3 Access Optimization"
    }
  )
}

# 현재 AWS 계정 ID 조회 (필요시 사용)
data "aws_caller_identity" "current" {}