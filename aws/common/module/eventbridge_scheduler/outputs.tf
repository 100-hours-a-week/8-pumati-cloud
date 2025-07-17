output "event_rule_name" {
  description = "Name of the CloudWatch Event Rule"
  value       = aws_cloudwatch_event_rule.this.name
}

output "event_rule_arn" {
  description = "ARN of the CloudWatch Event Rule"
  value       = aws_cloudwatch_event_rule.this.arn
}

output "event_target_id" {
  description = "ID of the CloudWatch Event Target"
  value       = aws_cloudwatch_event_target.this.target_id
}

output "lambda_permission_statement_id" {
  description = "Statement ID of the Lambda permission"
  value       = aws_lambda_permission.this.statement_id
}
