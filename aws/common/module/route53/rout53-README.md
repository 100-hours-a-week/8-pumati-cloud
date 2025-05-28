# route53.tf
# 사용 중인 도메인(Hosted Zone)을 찾기 위한 데이터 소스
data "aws_route53_zone" "this" {
  name         = var.zone_name       # 예: "tebutebu.com" — 사용할 도메인 이름
  private_zone = false               # 공개 도메인인지 여부 (true면 VPC 내부용)
}

# 해당 Hosted Zone에 레코드를 생성하는 리소스
resource "aws_route53_record" "this" {
  zone_id = data.aws_route53_zone.this.zone_id  # 위에서 찾은 도메인의 zone_id 사용

  name    = var.record_name       # 예: "app.tebutebu.com" 또는 "tebutebu.v2.com" — 생성할 레코드의 FQDN
  type    = var.record_type       # 레코드 타입 (기본은 "A", 필요 시 "CNAME", "TXT" 등)
  ttl     = var.ttl               # TTL 값 (기본 300초 = 5분)
  records = var.records           # 실제로 등록할 IP 주소나 도메인 값 (리스트형)
}

#예시
zone_name   = "tebutebu.com"
record_name = "tebutebu.v2.com"
record_type = "A"
ttl         = 300
records     = ["3.34.114.86"]
> 실제 Route 53 콘솔에선 tebutebu.v2.com이라는 이름의 A 레코드가 IP 3.34.114.86로 연결됨
#---------------------------------------------------------------------------------------------------------#
# variables.tf
variable "records" {
  description = "레코드에 등록할 IP 또는 값 목록"
  type        = list(string)
}
Q. 이거 왜 type  = list(string)임? 단일로 연결하면 안댐?

A.
왜 리스트여야 하는가?
aws_route53_record는 한 번에 여러 레코드 값을 설정할 수 있는 구조를 가짐

예: 하나의 A 레코드에 여러 IP를 등록할 수도 있음
```
records = ["3.34.114.86", "3.34.114.87"]
```
따라서 반드시 이렇게 감싸야 함
```
records = [var.frontend_public_ip]
```

#---------------------------------------------------------------------------------------------------------#
# outputs.tf

fqdn이란?
Fully Qualified Domain Name의 약자로,
"완전히 정규화된 도메인 이름"을 의미. 즉, 도메인의 전체 경로를 포함한 이름.

```
name = "tebutebu.v2.com"
zone = "tebutebu.com"
```
이 경우 aws_route53_record.this.fqdn의 결과는:
>> "tebutebu.v2.com."
마지막 .까지 포함된 것이 FQDN의 형식.

왜 출력하는가?
Terraform에서 이 값을 output으로 제공하면,

나중에 CD, ALB 리다이렉트, HTTPS 인증서 검증 등에서 자동으로 도메인 주소를 참조할 수 있고
콘솔에서 terraform output record_fqdn으로 정확한 도메인 연결 결과를 검증할 수 있음

실제 출력 예시
terraform output record_fqdn
> "tebutebu.v2.com."
