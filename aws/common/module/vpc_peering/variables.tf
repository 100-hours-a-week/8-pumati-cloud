variable "project_name" {
  type = string
}
variable "environment" {
  type = string
}
variable "tags" {
  type = map(string)
}

variable "requester_vpc_id" {
  type        = string
  description = "요청자 VPC ID"
}
variable "requester_vpc_cidr" {
  type        = string
  description = "요청자 VPC의 CIDR 블록"
}
variable "requester_route_table_id" {
  type        = string
  description = "요청자 VPC의 라우팅 테이블 ID"
}

variable "accepter_vpc_id" {
  type        = string
  description = "수락자 VPC ID"
}
variable "accepter_vpc_cidr" {
  type        = string
  description = "수락자 VPC의 CIDR 블록"
}
variable "accepter_route_table_ids" {
  type        = list(string)
  description = "수락자 VPC의 라우팅 테이블 ID 목록"
  default     = []
}

variable "enable_reverse_route" {
  type        = bool
  description = "수락자 → 요청자 방향 라우트를 생성할지 여부"
  default     = false
}
