resource "aws_vpc_peering_connection" "this" {
  vpc_id        = var.requester_vpc_id
  peer_vpc_id   = var.accepter_vpc_id
  auto_accept   = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-vpc-peering"
  })
}

# 요청자 → 수락자
resource "aws_route" "requester_to_accepter" {
  route_table_id            = var.requester_route_table_id
  destination_cidr_block    = var.accepter_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}

# 수락자 → 요청자 (선택적)
resource "aws_route" "accepter_to_requester" {
  count                     = var.enable_reverse_route ? length(var.accepter_route_table_ids) : 0

  route_table_id            = var.accepter_route_table_ids[count.index]
  destination_cidr_block    = var.requester_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this.id
}
