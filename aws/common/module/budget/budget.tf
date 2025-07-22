resource "aws_budgets_budget" "this" {
  name              = "${var.project_name}-${var.environment}-${var.service_name}-budget"
  budget_type       = "COST"
  limit_amount      = var.budget_limit
  limit_unit        = "USD"
  time_unit         = "MONTHLY"

  time_period_start = var.start_time
  time_period_end   = var.end_time

  # 통합된 알림 설정 (이메일 + SNS)
  dynamic "notification" {
    for_each = var.notification_settings
    content {
      comparison_operator = "GREATER_THAN"
      threshold           = notification.value.threshold
      threshold_type      = notification.value.threshold_type
      notification_type   = notification.value.notification_type
      
      # 이메일 알림은 항상 포함
      subscriber_email_addresses = var.alert_email
      
      # SNS 알림은 enable_sns가 true일 때만 포함
      subscriber_sns_topic_arns = notification.value.enable_sns && var.sns_topic_arn != null ? [var.sns_topic_arn] : []
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-${var.service_name}-budget"
  })
}
