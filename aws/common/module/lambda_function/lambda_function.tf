# module/lambda_function/main.tf

data "archive_file" "lambda" {
  type        = "zip"
  source_file = var.lambda_source_file
  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "this" {
  function_name = "${var.project_name}-${var.environment}-${var.service_name}-lambda"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  handler          = var.handler
  runtime          = var.runtime
  role             = var.lambda_role_arn
  timeout          = var.timeout
  publish          = var.publish

  environment {
    variables = var.environment_variables
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-${var.service_name}-lambda"
  })
}
