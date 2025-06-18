resource "aws_launch_template" "this" {
  name_prefix   = "${var.project_name}-${var.environment}-${var.service_name}-lt"
  image_id      = var.instance_ami
  instance_type = var.instance_type
  key_name      = var.instance_key_name
  user_data     = var.user_data_base64

  vpc_security_group_ids = var.security_group_ids

  iam_instance_profile {
    name = var.iam_instance_profile
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.root_volume_size
      volume_type           = var.root_volume_type
      delete_on_termination = true
      encrypted             = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = var.tags
  }
}

resource "aws_autoscaling_group" "this" {
  name                      = "${var.project_name}-${var.environment}-${var.service_name}-asg"
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  vpc_zone_identifier       = [var.subnet_id]
  target_group_arns         = var.target_group_arns
  health_check_type         = var.health_check_type
  health_check_grace_period = var.health_check_grace_period

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-${var.service_name}"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}