resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = merge(tomap({
    Name = "${var.project_name}-${var.environment}-vpc"}),
     var.tags)
}

resource "aws_subnet" "public_subnets_a" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.vpc_public_subnets_a_cidr
  map_public_ip_on_launch = true
  availability_zone       = var.vpc_az
  tags = merge(tomap({
    Name = "${var.project_name}-${var.environment}-subnet-public-a"}),
     var.tags)
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = merge(tomap({
    Name = "${var.project_name}-${var.environment}-igw"}),
     var.tags)
}

resource "aws_route_table" "public_rt_a" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = merge(tomap({
    Name = "${var.project_name}-${var.environment}-public-rt-a"}),
     var.tags)
}

resource "aws_route_table_association" "public_rta_a" {
  subnet_id      = aws_subnet.public_subnets_a.id
  route_table_id = aws_route_table.public_rt_a.id
}
