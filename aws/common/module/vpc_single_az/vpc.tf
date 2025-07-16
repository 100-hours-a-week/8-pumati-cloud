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
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.az
  map_public_ip_on_launch = var.public_subnet_map_public_ip

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-public-subnet"
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
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ----------------------------------------------------------------------------------------------------------------------
# 서비스 서브넷
# ----------------------------------------------------------------------------------------------------------------------
resource "aws_subnet" "service" {
  count                   = var.enable_service_subnet ? 1 : 0
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.service_subnet_cidr
  availability_zone       = var.az
  map_public_ip_on_launch = var.service_subnet_map_public_ip

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-service-subnet"
  })
}

resource "aws_route_table" "service" {
  count  = var.enable_service_subnet ? 1 : 0
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-service-rt"
  })
}

resource "aws_route_table_association" "service" {
  count          = var.enable_service_subnet ? 1 : 0
  subnet_id      = aws_subnet.service[0].id
  route_table_id = aws_route_table.service[0].id
}
# ----------------------------------------------------------------------------------------------------------------------
# 데이터베이스 서브넷
# ----------------------------------------------------------------------------------------------------------------------
resource "aws_subnet" "db" {
  count                   = var.enable_db_subnet ? 1 : 0
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.db_subnet_cidr
  availability_zone       = var.az
  map_public_ip_on_launch = var.db_subnet_map_public_ip

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-db-subnet"
  })
}

resource "aws_route_table" "db" {
  count  = var.enable_db_subnet ? 1 : 0
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-db-rt"
  })
}

resource "aws_route_table_association" "db" {
  count          = var.enable_db_subnet ? 1 : 0
  subnet_id      = aws_subnet.db[0].id
  route_table_id = aws_route_table.db[0].id
}
