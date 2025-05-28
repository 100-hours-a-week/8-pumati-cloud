variable "project_name"     {
    type = string
    description = "프로젝트 이름"
}

variable "environment"      {
    type = string
    description = "환경"
}

variable "instance_name"    {
    type = string
    description = "인스턴스 이름"
}

variable "tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}

variable "inline_policy_json" {
  type = string
  description = "IAM Role에 연결할 inline policy (JSON 문자열)"
}
