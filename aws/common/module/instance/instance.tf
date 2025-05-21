# ------------------------------------------------------------
# EC2 인스턴스
# ------------------------------------------------------------
resource "aws_instance" "instance" {
  ami           = var.instance_ami
  instance_type = var.instance_type
  key_name      = var.instance_key_name
  subnet_id     = var.subnet_id

  iam_instance_profile = var.iam_instance_profile

  vpc_security_group_ids = [var.security_group_id]

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = var.root_volume_type
    encrypted   = true
    tags        = var.tags
  }

  tags = var.tags

  user_data = var.user_data
}
