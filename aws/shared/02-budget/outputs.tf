# ----------------------------------------------------------------------------------------------------------------------
# Budget 정보
# ----------------------------------------------------------------------------------------------------------------------
output "budget_name" {
  description = "예산 리소스의 이름"
  value       = module.budget.budget_name
}

output "budget_limit_amount" {
  description = "설정된 예산 한도 (USD)"
  value       = module.budget.budget_limit_amount
}

output "budget_time_unit" {
  description = "예산의 시간 단위 (예: MONTHLY)"
  value       = module.budget.budget_time_unit
}

# ----------------------------------------------------------------------------------------------------------------------
# Budget 알림 경로
# ----------------------------------------------------------------------------------------------------------------------
output "budget_sns_topic_arn" {
  description = "Budget 알림에 연결된 SNS Topic ARN"
  value       = module.budget.sns_topic_arn
}
