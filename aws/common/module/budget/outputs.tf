output "budget_name" {
  value = aws_budgets_budget.this.name
}

output "budget_limit_amount" {
  description = "설정된 예산 한도 (USD)"
  value       = aws_budgets_budget.this.limit_amount
}

output "budget_time_unit" {
  description = "예산의 시간 단위 (예: MONTHLY)"
  value       = aws_budgets_budget.this.time_unit
}

output "sns_topic_arn" {
  description = "Budget 알림에 연결된 SNS Topic ARN" 
  value       = var.sns_topic_arn
}
