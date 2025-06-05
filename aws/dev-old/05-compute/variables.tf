variable "backend_env_content" {
  description = "Backend .env file content"
  type        = string
  sensitive   = true
}

variable "frontend_env_content" {
  description = "Frontend .env file content"
  type        = string
  sensitive   = true
}
