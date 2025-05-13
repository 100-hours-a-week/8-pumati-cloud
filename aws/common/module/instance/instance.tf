# ------------------------------------------------------------
# 프론트엔드 인스턴스
# ------------------------------------------------------------
resource "aws_instance" "frontend" {
  count = var.instance_type == "frontend" ? 1 : 0

  ami           = var.instance_ami
  instance_type = var.instance_size
  key_name      = var.instance_key_name
  subnet_id     = var.subnet_id

  vpc_security_group_ids = [var.frontend_security_group_id]

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = var.root_volume_type
    encrypted   = true
    tags        = merge(var.tags, {
      Name = "${var.project_name}-${var.environment}-frontend-root"
    })
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-frontend"
  })
}
# ------------------------------------------------------------
# 백엔드 인스턴스
# ------------------------------------------------------------
resource "aws_instance" "backend" {
  count = var.instance_type == "backend" ? 1 : 0

  ami           = var.instance_ami
  instance_type = var.instance_size
  key_name      = var.instance_key_name
  subnet_id     = var.subnet_id

  vpc_security_group_ids = [var.backend_security_group_id]

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = var.root_volume_type
    encrypted   = true
    tags        = merge(var.tags, {
      Name = "${var.project_name}-${var.environment}-backend-root"
    })
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-backend"
  })
}

# ------------------------------------------------------------
# DB 인스턴스
# ------------------------------------------------------------
# resource "aws_instance" "db" {
#   count = var.instance_type == "db" ? 1 : 0

#   ami           = var.instance_ami
#   instance_type = var.instance_size
#   key_name      = var.instance_key_name
#   subnet_id     = var.subnet_id

#   vpc_security_group_ids = [var.db_security_group_id]

#   root_block_device {
#     volume_size = var.root_volume_size
#     volume_type = var.root_volume_type
#     encrypted   = true
#     tags        = merge(var.tags, {
#       Name = "${var.project_name}-${var.environment}-db-root"
#     })
#   }

#   tags = merge(var.tags, {
#     Name = "${var.project_name}-${var.environment}-db"
#   })
# }