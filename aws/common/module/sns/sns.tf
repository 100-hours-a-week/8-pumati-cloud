resource "aws_sns_topic" "this" {
  name = "${var.project_name}-${var.environment}-${var.service_name}-sns-topic"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-${var.service_name}-sns-topic"
  })
}

resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = aws_sns_topic.this.arn
  protocol  = "lambda"
  endpoint  = var.lambda_function_arn
}

resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS-${var.project_name}-${var.environment}-${var.service_name}"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.this.arn
}
