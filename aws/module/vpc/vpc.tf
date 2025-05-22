# modules/vpc/main.tf
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

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.az
  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-public-subnet"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "service" {
  count             = var.enable_service_subnet ? 1 : 0
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.service_subnet_cidr
  availability_zone = var.az

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-service-subnet"
  })
}

resource "aws_subnet" "db" {
  count             = var.enable_db_subnet ? 1 : 0
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.db_subnet_cidr
  availability_zone = var.az

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-db-subnet"
  })
}
