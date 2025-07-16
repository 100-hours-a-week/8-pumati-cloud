resource "aws_route" "nat_route" {
  route_table_id         = var.route_table_id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = var.nat_network_interface_id
}
