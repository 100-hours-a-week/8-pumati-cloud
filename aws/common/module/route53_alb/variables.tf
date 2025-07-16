variable "zone_name" {
  description = "예: tebutebu.com"
  type        = string
}

variable "record_name" {
  description = "예: test.tebutebu.com"
  type        = string
}

variable "alias_name" {
  description = "ALB의 DNS 이름"
  type        = string
}

variable "alias_zone_id" {
  description = "ALB의 호스팅 zone ID"
  type        = string
}
