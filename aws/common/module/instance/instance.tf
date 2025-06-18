resource "aws_instance" "this" {
  ami                    = var.instance_ami
  instance_type          = var.instance_type
  key_name               = var.instance_key_name
  subnet_id              = var.subnet_id
  iam_instance_profile   = var.iam_instance_profile
  vpc_security_group_ids = var.security_group_ids
  source_dest_check      = var.source_dest_check

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    delete_on_termination = true
    encrypted             = true
    tags                  = var.tags
  }

  user_data = var.user_data

  monitoring                      = var.enable_monitoring
  disable_api_termination         = var.disable_api_termination
  instance_initiated_shutdown_behavior = var.shutdown_behavior

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-${var.service_name}"
  })
}

# 선택적으로 EIP를 인스턴스에 연결
resource "aws_eip" "this" {
  count    = var.enable_eip ? 1 : 0
  domain   = "vpc"
  instance = aws_instance.this.id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-${var.service_name}-eip"
  })
}
