# 짧은 가용영역 이름을 전체 이름으로 변환
locals {
  # azs 값이 짧은 형태(a, c)인지 긴 형태(ap-northeast-2a)인지 확인하여 변환
  full_azs = [
    for az in var.azs : 
    length(az) == 1 ? "ap-northeast-2${az}" : az
  ]
  
  # Name 태그용 짧은 이름 추출 (ap-northeast-2a -> a)
  short_azs = [
    for az in local.full_azs :
    substr(az, -1, 1)
  ]
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-igw"
  })
}

# ----------------------------------------------------------------------------------------------------------------------
# 퍼블릭 서브넷
# ----------------------------------------------------------------------------------------------------------------------
resource "aws_subnet" "public" {
  # local.full_azs에 들어있는 가용영역(AZ)의 수만큼 리소스를 반복 생성
  count                   = length(local.full_azs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = local.full_azs[count.index]
  map_public_ip_on_launch = var.public_subnet_map_public_ip

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-public-subnet-${local.short_azs[count.index]}"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-public-rt"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count          = length(local.full_azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}


# ----------------------------------------------------------------------------------------------------------------------
# 서비스 서브넷
# ----------------------------------------------------------------------------------------------------------------------
resource "aws_subnet" "service" {
  count = var.enable_service_subnet ? length(local.full_azs) : 0

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.service_subnet_cidrs[count.index]
  availability_zone       = local.full_azs[count.index]
  map_public_ip_on_launch = var.service_subnet_map_public_ip

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-service-subnet-${local.short_azs[count.index]}"
  })
}

resource "aws_route_table" "service" {
  count  = var.enable_service_subnet ? length(local.full_azs) : 0
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-service-rt-${local.short_azs[count.index]}"
  })
}

resource "aws_route_table_association" "service" {
  count          = var.enable_service_subnet ? length(local.full_azs) : 0
  subnet_id      = aws_subnet.service[count.index].id
  route_table_id = aws_route_table.service[count.index].id
}
# ----------------------------------------------------------------------------------------------------------------------
# 데이터베이스 서브넷
# ----------------------------------------------------------------------------------------------------------------------
resource "aws_subnet" "db" {
  count                   = var.enable_db_subnet ? length(local.full_azs) : 0
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.db_subnet_cidrs[count.index]
  availability_zone       = local.full_azs[count.index]
  map_public_ip_on_launch = var.db_subnet_map_public_ip

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-db-subnet-${local.short_azs[count.index]}"
  })
}


resource "aws_route_table" "db" {
  count  = var.enable_db_subnet ? length(local.full_azs) : 0
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-db-rt-${local.short_azs[count.index]}"
  })
}

resource "aws_route_table_association" "db" {
  count          = var.enable_db_subnet ? length(local.full_azs) : 0
  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.db[count.index].id
}
