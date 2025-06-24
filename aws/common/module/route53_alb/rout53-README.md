# Terraform Module: route53_alb

이 모듈은 AWS Application Load Balancer(ALB)에 도메인 또는 서브도메인을 연결하기 위한 Route 53 **Alias A 레코드**를 생성합니다.

## 📦 목적

- ALB에만 연결하는 간단한 도메인 레코드 관리
- 일반 A/CNAME 레코드가 아닌 AWS 리소스를 위한 **Alias 레코드 전용**
- `test.tebutebu.com` → ALB DNS 로 연결되는 경우에 사용

---

## 📁 모듈 구조

```
modules/
└── route53-alb/
    ├── main.tf
    └── variables.tf
```

---

## 🔧 입력 변수 (variables.tf)

```hcl
variable "zone_name" {
  description = "Route 53 호스팅 영역 이름 (예: tebutebu.com)"
  type        = string
}

variable "record_name" {
  description = "레코드 이름 (예: test.tebutebu.com)"
  type        = string
}

variable "alias_name" {
  description = "ALB의 DNS 이름 (예: pumati-alb-123.ap-northeast-2.elb.amazonaws.com)"
  type        = string
}

variable "alias_zone_id" {
  description = "ALB가 속한 호스팅 영역의 zone ID"
  type        = string
}
```

---

## 🛠 리소스 정의 (main.tf)

```hcl
data "aws_route53_zone" "this" {
  name         = var.zone_name
  private_zone = false
}

resource "aws_route53_record" "this" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.record_name
  type    = "A"

  alias {
    name                   = var.alias_name
    zone_id                = var.alias_zone_id
    evaluate_target_health = true
  }
}
```

---

## 🚀 사용 예시

```hcl
module "route53_test_subdomain" {
  source = "../../modules/route53-alb"

  zone_name       = "tebutebu.com"
  record_name     = "test.tebutebu.com"
  alias_name      = module.alb.alb_dns_name
  alias_zone_id   = module.alb.alb_zone_id
}
```

---

## ✅ 출력 예시 (선택적)

```hcl
output "record_fqdn" {
  description = "생성된 Route 53 레코드의 전체 도메인 이름"
  value       = aws_route53_record.this.fqdn
}
```

---

## 📝 참고 사항

- ALB와 같은 AWS 리소스는 고정 IP가 없기 때문에 일반 A 레코드(`records = [...]`)로 연결할 수 없습니다.
- 이 모듈은 **Alias A 레코드 전용**으로 구성되어 있으므로, 일반적인 A, CNAME 레코드는 따로 모듈화가 필요합니다.
