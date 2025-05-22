 03-security 디렉토리는 일반적으로 보안 그룹(SG), 네트워크 ACL(NACL), 보안 관련 IAM 설정 같은 네트워크 계층의 보안 구성 요소를 정의


# dynamic "ingress"구조는 aws_security_group 리소스 내부에서 동적으로 ingress 규칙을 생성할 때 사용
 dynamic "ingress" {
  for_each = var.ingress_rules
  content {
    from_port        = ingress.value.from_port
    to_port          = ingress.value.to_port
    protocol         = ingress.value.protocol
    cidr_blocks      = lookup(ingress.value, "cidr_blocks", null)
    security_groups  = lookup(ingress.value, "security_groups", null)
    description      = lookup(ingress.value, "description", null)
  }
}

var.ingress_rules라는 리스트에 정의된 각 인바운드 규칙을 순회하면서
aws_security_group의 ingress 블록을 동적으로 여러 개 생성하는 구조

<필드명	설명>
from_port : 시작 포트 (예: 22)
to_port	: 끝 포트 (예: 22)
protocol : tcp, udp, icmp, -1(모두) 등
cidr_blocks : 허용할 IP 범위. 보통 ["0.0.0.0/0"], "YOUR_IP/32" 등
security_groups : 특정 보안 그룹에서만 허용 (예: 프론트 SG만 백엔드 접속 가능)
description	: 규칙 설명 (Cloud UI에서도 보임)

<"for_each = var.ingress_rules">
- var.ingress_rules는 list of objects
```
[
  {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  },
  ...
]
```
- 이 리스트를 반복하면서 각 항목을 ingress라는 이름의 변수로 받음 (ingress.value)

<"content { ... }">
- 반복하면서 생성될 실제 ingress 블록의 내부 내용
- aws_security_group에서 사용하는 표준 필드로 구성됨


<"lookup()" 함수>
lookup(ingress.value, "cidr_blocks", null)
- ingress.value 객체 안에 "cidr_blocks" 키가 있는지 확인하고, 있으면 그 값을 반환
- 없으면 null 반환
- 이 방식으로 선택적인 필드를 처리할 수 있음 (옵셔널 필드)

### 
보안그룹은 아래 형식으로 만들어짐
```
module "<logical_name>" {
  source = "<상대 또는 원격 모듈 경로>"

  # 공통 값 (모든 모듈에서 동일하게 사용)
  project_name  = local.project_name
  environment   = local.environment
  region        = local.region
  tags          = local.common_tags
  instance_name = "<모듈 별 고유 이름>" # 예: frontend, backend, jenkins

  # 리소스 고유값 (리소스 목적/기능과 관련된 필드)
  name          = "${local.project_name}-${local.environment}-<logical_name>"
  description   = "<모듈 설명>"
  vpc_id        = data.terraform_remote_state.network.outputs.vpc_id

  # 리소스별 설정값 (복잡하거나 배열 구조 등)
  ingress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["YOUR_IP/32"]
      description = "SSH"
    },
    # ... 더 많은 규칙 추가 가능
  ]

  # 필요한 경우 추가적인 옵션
  # enable_feature = true
}
```

egress는 모듈내부에서 전체 허용으로 해뒀으므로 안해도댐

ARN	설명
"arn:aws:s3:::s3-common-storage-pumati"	버킷 자체 (예: ListBucket 권한 필요 시)
"arn:aws:s3:::s3-common-storage-pumati/*"	버킷 내부 객체들 (예: GetObject, PutObject)