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
# Lambda 함수 설정
#------------------------------------------------------------------------------

variable "lambda_source_file" {
  description = "Path to the Lambda source file"
  type        = string
}

variable "handler" {
  description = "Handler of the Lambda function"
  type        = string
}

variable "runtime" {
  description = "Lambda runtime environment"
  type        = string
}

variable "lambda_role_arn" {
  description = "IAM Role ARN for the Lambda function"
  type        = string
}
variable "timeout" {
  description = "Lambda execution timeout in seconds"
  type        = number
}
variable "publish" {
  description = "Whether to publish a new version on update"
  type        = bool
}

variable "environment_variables" {
  description = "Environment variables for the Lambda function"
  type        = map(string)
}
