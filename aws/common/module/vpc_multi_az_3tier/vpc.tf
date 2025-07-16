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
  # var.azs에 들어있는 가용영역(AZ)의 수만큼 리소스를 반복 생성
  count                   = length(var.azs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = var.public_subnet_map_public_ip

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-public-subnet-${var.azs[count.index]}"
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
  count          = length(var.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}


# ----------------------------------------------------------------------------------------------------------------------
# 서비스 서브넷
# ----------------------------------------------------------------------------------------------------------------------
resource "aws_subnet" "service" {
  count = var.enable_service_subnet ? length(var.azs) : 0

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.service_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = var.service_subnet_map_public_ip

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-service-subnet-${var.azs[count.index]}"
  })
}

resource "aws_route_table" "service" {
  count  = var.enable_service_subnet ? length(var.azs) : 0
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-service-rt-${var.azs[count.index]}"
  })
}

resource "aws_route_table_association" "service" {
  count          = var.enable_service_subnet ? length(var.azs) : 0
  subnet_id      = aws_subnet.service[count.index].id
  route_table_id = aws_route_table.service[count.index].id
}
# ----------------------------------------------------------------------------------------------------------------------
# 데이터베이스 서브넷
# ----------------------------------------------------------------------------------------------------------------------
resource "aws_subnet" "db" {
  count                   = var.enable_db_subnet ? length(var.azs) : 0
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.db_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = var.db_subnet_map_public_ip

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-db-subnet-${var.azs[count.index]}"
  })
}


resource "aws_route_table" "db" {
  count  = var.enable_db_subnet ? length(var.azs) : 0
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-db-rt-${var.azs[count.index]}"
  })
}

resource "aws_route_table_association" "db" {
  count          = var.enable_db_subnet ? length(var.azs) : 0
  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.db[count.index].id
}
