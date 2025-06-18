output "asg_name" {
  value = aws_autoscaling_group.this.name
}

output "asg_arn" {
  value = aws_autoscaling_group.this.arn
} 

output "asg_id" {
  value = aws_autoscaling_group.this.id
}

output "launch_template_id" {
  value = aws_launch_template.this.id
}

output "launch_template_name" {
  value = aws_launch_template.this.name
}

