# modules/route53/variables.tf
variable "zone_name" {
  description = "도메인 이름 (예: example.com)"
  type        = string
}

variable "record_name" {
  description = "레코드 이름 (예: app.example.com)"
  type        = string
}

variable "record_type" {
  description = "레코드 타입 (예: A, CNAME, etc)"
  type        = string
}

variable "ttl" {
  description = "레코드 TTL 값"
  type        = number
}

variable "records" {
  description = "레코드에 등록할 IP 또는 값 목록"
  type        = list(string)
}