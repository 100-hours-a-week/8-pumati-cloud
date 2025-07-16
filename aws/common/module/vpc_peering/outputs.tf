output "vpc_peering_connection_id" {
  value = aws_vpc_peering_connection.this.id
}

output "accepter_route_table_ids" {
  description = "Accepter 측에 설정된 라우팅 테이블 ID 목록"
  value       = aws_route.accepter_to_requester[*].route_table_id
}