output "lambda_function_name" {
  description = "The name of the Lambda function that schedules EC2 instances"
  value       = module.ec2_scheduler_lambda.lambda_function_name
}

output "lambda_function_arn" {
  description = "The ARN of the Lambda function"
  value       = module.ec2_scheduler_lambda.lambda_arn
}

output "start_schedule_rule_name" {
  description = "Name of the EventBridge rule for starting EC2"
  value       = module.start_ec2_schedule.event_rule_name
}

output "stop_schedule_rule_name" {
  description = "Name of the EventBridge rule for stopping EC2"
  value       = module.stop_ec2_schedule.event_rule_name
}

output "start_schedule_rule_arn" {
  description = "ARN of the EventBridge rule for starting EC2"
  value       = module.start_ec2_schedule.event_rule_arn
}

output "stop_schedule_rule_arn" {
  description = "ARN of the EventBridge rule for stopping EC2"
  value       = module.stop_ec2_schedule.event_rule_arn
}
