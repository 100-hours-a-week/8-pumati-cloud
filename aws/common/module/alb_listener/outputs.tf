output "https_listener_arn" {
  description = "443 HTTPS 리스너 ARN"
  value       = try(aws_lb_listener.https[0].arn, null)
}

output "http_listener_arn" {
  description = "80 HTTP 리디렉션 리스너 ARN"
  value       = try(aws_lb_listener.http_redirect[0].arn, null)
}

