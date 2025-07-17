variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "environment" {
  description = "환경 이름 (예: dev, prod)"
  type        = string
}

variable "service_name" {
  description = "서비스 이름 (예: frontend, backend, management)"
  type        = string
}

variable "tags" {
  description = "리소스에 추가할 태그"
  type        = map(string)
  default     = {}
}

#------------------------------------------------------------------------------
# EventBridge Scheduler 설정
#------------------------------------------------------------------------------

variable "rule_name" {
  description = "Name of the EventBridge rule"
  type        = string
}

variable "schedule_expression" {
  description = "Schedule expression for the rule (e.g., rate(5 minutes) or cron(0 20 * * ? *))"
  type        = string
}

variable "description" {
  description = "Description of the EventBridge rule"
  type        = string
  default     = ""
}

variable "target_id" {
  description = "ID of the EventBridge target"
  type        = string
}

variable "lambda_arn" {
  description = "ARN of the Lambda function to trigger"
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "input_json" {
  description = "JSON input to pass to the Lambda function"
  type        = string
  default     = "{}"
}
