output "vpc_peering_connection_id" {
  value       = aws_vpc_peering_connection.this.id
  description = "ID of the VPC peering connection"
}
