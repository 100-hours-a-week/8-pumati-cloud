variable "domain_name" {
  description = "인증서를 발급할 도메인 이름 (예: example.com)"
  type = string
}

variable "tags" {
  description = "리소스에 적용할 태그"
  type    = map(string)
}

variable "zone_id" {
  description = "도메인의 Route53 호스팅 영역 ID"
  type = string
}

variable "subject_alternative_names" {
  description = "인증서에 추가할 대체 도메인 이름 목록 (예: [\"*.example.com\"])"
  type    = list(string)
}