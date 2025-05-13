# AWS Common 모듈 사용 가이드

## 소개
이 모듈은 테라폼을 사용하여 AWS 인프라를 구축할 때 필요한 공통 변수들을 정의합니다. 프로젝트 전반에 걸쳐 일관된 설정을 유지하기 위해 사용됩니다.

## 변수 정의
이 모듈은 다음과 같은 공통 변수들을 정의합니다:
- `project_name`: 프로젝트 이름
- `environment`: 환경(dev, staging, prod)
- `region`: AWS 리전
- `common_tags`: 모든 리소스에 적용될 공통 태그
- `domain_name`: 서비스 도메인 이름
- `tfstate_bucket`: 테라폼 상태를 저장할 S3 버킷 이름
- `tfstate_region`: 테라폼 상태 버킷이 위치한 리전

## 사용 방법

### 모듈 참조 설정
다른 테라폼 모듈에서 common 모듈의 변수를 사용하려면 `providers.tf` 파일에 아래 내용을 추가하세요:

```hcl
# Common 모듈의 상태를 참조
data "terraform_remote_state" "common" {
  backend = "s3"
  config = {
    bucket = "s3-terraform-pumati"
    key    = "aws/prod/common/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# Common 모듈의 출력 값 사용
locals {
  project_name = data.terraform_remote_state.common.outputs.project_name
  region       = data.terraform_remote_state.common.outputs.region
  environment  = data.terraform_remote_state.common.outputs.environment
  common_tags  = data.terraform_remote_state.common.outputs.common_tags
  domain_name  = data.terraform_remote_state.common.outputs.domain_name
}
```

### 변수 사용
변수를 사용할 때는 `local` 블록을 통해 접근합니다:

```hcl
resource "aws_s3_bucket" "example" {
  bucket = "${local.project_name}-${local.environment}-bucket"
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-bucket"
    }
  )
}
```

## 모듈 초기화
이 모듈을 처음 사용하기 전에 초기화해야 합니다:

```bash
cd aws/prod/01-common
terraform init
terraform apply
```

### 변수 값 변경 (예: Owner 태그)
특정 변수 값을 변경하고 싶을 때는 명령줄에서 `-var` 옵션을 사용할 수 있습니다:

```bash
# Owner 태그 변경 예시
terraform apply -var='common_tags={"ManagedBy":"Terraform","Project":"pumati","Environment":"prod","Owner":"rowan"}'
```

또는 더 간단하게 `-var` 옵션으로 개별 맵 요소를 업데이트 할 수 있습니다:

```bash
terraform apply -var='common_tags.Owner=rowan'
```

## 참고 사항
- 항상 다른 모듈을 초기화하기 전에 common 모듈을 먼저 적용(apply)하세요.
- common 모듈의 변수를 변경할 경우, 해당 변수를 사용하는 모든 모듈을 다시 적용해야 합니다.
- 백엔드 설정에서 올바른 경로(`aws/prod/common/terraform.tfstate`)를 사용하고 있는지 확인하세요.