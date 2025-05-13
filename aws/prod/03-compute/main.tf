# ------------------------------------------------------------
# 프론트엔드 인스턴스
# ------------------------------------------------------------
resource "aws_instance" "frontend" {
  ami           = var.instance_ami_linux
  instance_type = var.instance_size
  key_name      = var.instance_key_name
  subnet_id     = local.public_subnet_id

  vpc_security_group_ids = [local.frontend_sg_id]

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = var.root_volume_type
    encrypted   = true
    tags        = merge(local.common_tags, {
      Name = "${local.project_name}-${local.environment}-frontend-root"
    })
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-frontend"
  })
}

# ------------------------------------------------------------
# 백엔드 인스턴스
# ------------------------------------------------------------
resource "aws_instance" "backend" {
  ami           = var.instance_ami_linux
  instance_type = var.instance_size
  key_name      = var.instance_key_name
  subnet_id     = local.public_subnet_id

  vpc_security_group_ids = [local.backend_sg_id]

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = var.root_volume_type
    encrypted   = true
    tags        = merge(local.common_tags, {
      Name = "${local.project_name}-${local.environment}-backend-root"
    })
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-backend"
  })
}

# ------------------------------------------------------------
# DB 인스턴스
# ------------------------------------------------------------
# resource "aws_instance" "db" {
#   ami           = var.instance_ami_linux
#   instance_type = var.instance_size
#   key_name      = var.instance_key_name
#   subnet_id     = local.public_subnet_id

#   vpc_security_group_ids = [local.db_sg_id]

#   root_block_device {
#     volume_size = var.root_volume_size
#     volume_type = var.root_volume_type
#     encrypted   = true
#     tags        = merge(local.common_tags, {
#       Name = "${local.project_name}-${local.environment}-db-root"
#     })
#   }

#   tags = merge(local.common_tags, {
#     Name = "${local.project_name}-${local.environment}-db"
#   })
# }