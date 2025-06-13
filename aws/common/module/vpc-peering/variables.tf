variable "project_name" {
  type        = string
  description = "Project name for naming"
}

variable "environment" {
  type        = string
  description = "Environment (e.g. dev, prod)"
}

variable "tags" {
  type        = map(string)
  description = "Common tags"
  default     = {}
}

variable "requester_vpc_id" {
  type        = string
  description = "ID of the VPC initiating the peering"
}

variable "accepter_vpc_id" {
  type        = string
  description = "ID of the VPC being peered to"
}

variable "destination_cidr_block" {
  type        = string
  description = "CIDR block to route to (accepter VPC CIDR)"
}

variable "requester_route_table_id" {
  type        = string
  description = "Route table ID of the requester VPC"
}

variable "auto_accept" {
  type        = bool
  default     = true
  description = "Whether to auto-accept the peering request"
}
