output "route_id" {
  description = "생성된 NAT 라우트 ID"
  value       = aws_route.nat_route.id
}
