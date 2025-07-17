resource "aws_cloudwatch_event_rule" "this" {
  name                = "${var.project_name}-${var.environment}-${var.service_name}-scheduler"
  schedule_expression = var.schedule_expression
  description         = var.description

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-${var.service_name}-scheduler"
  })
}

resource "aws_cloudwatch_event_target" "this" {
  rule      = aws_cloudwatch_event_rule.this.name
  target_id = "${var.project_name}-${var.environment}-${var.service_name}-target"
  arn       = var.lambda_arn
  input     = var.input_json
}

resource "aws_lambda_permission" "this" {
  statement_id  = "AllowEventBridgeInvoke-${var.project_name}-${var.environment}-${var.service_name}"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.this.arn
}
