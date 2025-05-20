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

resource "aws_subnet" "main_subnet_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.1.0.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-subnet-a"
  })
}

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

resource "aws_route_table_association" "subnet_assoc" {
  subnet_id      = aws_subnet.main_subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}

##############################
# 2. 보안 그룹 생성
##############################

# # ALB용 보안 그룹 (HTTP/HTTPS 허용)
# resource "aws_security_group" "alb_sg" {
#   name        = "alb-sg"
#   description = "Allow HTTP and HTTPS"
#   vpc_id      = aws_vpc.main.id

#   ingress {
#     description = "Allow HTTP"
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     description = "Allow HTTPS"
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "alb-sg"
#   }
# }

# # 프론트엔드 EC2용 보안 그룹 (ALB에서만 허용)
# resource "aws_security_group" "frontend_sg" {
#   name        = "frontend-sg"
#   description = "Allow traffic from ALB"
#   vpc_id      = aws_vpc.main.id

#   ingress {
#     from_port       = 80
#     to_port         = 80
#     protocol        = "tcp"
#     security_groups = [aws_security_group.alb_sg.id]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "frontend-sg"
#   }
# }

# # 백엔드 EC2용 보안 그룹 (ALB에서만 허용)
# resource "aws_security_group" "backend_sg" {
#   name        = "backend-sg"
#   description = "Allow traffic from ALB"
#   vpc_id      = aws_vpc.main.id

#   ingress {
#     from_port       = 80
#     to_port         = 80
#     protocol        = "tcp"
#     security_groups = [aws_security_group.alb_sg.id]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "backend-sg"
#   }
# }

# 이후의 var.alb_sg_id, var.frontend_sg_id, var.backend_sg_id 등에 이 값을 반영

# --- 이하 기존 코드 (Launch Template, Target Group 등) 유지 ---