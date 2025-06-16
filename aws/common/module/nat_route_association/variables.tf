variable "route_table_id" {
  description = "NAT 라우트를 추가할 대상 Route Table ID"
  type        = string
}

variable "nat_network_interface_id" {
  description = "라우팅 대상 NAT 인스턴스의 네트워크 인터페이스 ID"
  type        = string
}
