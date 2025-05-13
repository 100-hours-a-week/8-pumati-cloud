# AWS Static 모듈 구성 가이드

## 소개
이 모듈은 테라폼을 사용하여 AWS 인프라의 기본적인 정적 리소스(S3 버킷 등)를 생성합니다. 이 디렉토리는 로컬 상태 파일을 사용하며, 여기서 생성된 S3 버킷은 이후 다른 모든 테라폼 모듈의 상태 파일을 저장하는 데 사용됩니다.

## 생성되는 리소스
이 모듈에서는 다음과 같은 리소스들이 생성됩니다:
1. `s3-terraform-pumati`: 테라폼 상태 파일 저장용 S3 버킷
2. `s3-monitoring-logs-pumati`: 모니터링 로그 수집용 S3 버킷
3. `s3-common-storage-pumati`: 공용 스토리지용 S3 버킷

## 버킷 특성 및 설정
모든 버킷은 다음과 같은 특성을 가집니다:
- 버전 관리 활성화
- 서버 사이드 암호화(AES256) 적용
- 퍼블릭 액세스 차단
- 수명 주기 규칙 적용(이전 버전은 일정 기간 후 자동 삭제)
  - 테라폼 상태 버킷: 120일
  - 모니터링 로그 버킷: 90일
  - 공용 스토리지 버킷: 180일

## 사용 방법

### 초기 설정 및 배포
이 모듈을 처음 사용할 때는 다음 명령어로 초기화하고 배포합니다:

```bash
cd aws/prod/00-static
terraform init
terraform apply
```

### 다른 모듈에서 참조하기
01-common 이후의 모듈은 여기서 생성한 S3 버킷을 백엔드로 사용합니다. backend.tf 파일에 다음과 같이 설정하세요:

```hcl
terraform {
  backend "s3" {
    bucket       = "s3-terraform-pumati"
    key          = "aws/prod/{디렉토리명}/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}
```

### S3 버킷 정보 참조
다른 모듈에서 이 모듈의 출력값을 참조하려면 다음과 같이 설정하세요:

```hcl
data "terraform_remote_state" "static" {
  backend = "s3"
  config = {
    bucket = "s3-terraform-pumati"
    key    = "aws/prod/static/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# 사용 예시
locals {
  terraform_state_bucket = data.terraform_remote_state.static.outputs.terraform_state_bucket
  monitoring_logs_bucket = data.terraform_remote_state.static.outputs.monitoring_logs_bucket
  common_storage_bucket  = data.terraform_remote_state.static.outputs.common_storage_bucket
}
```

## 주의 사항
- 이 모듈은 로컬 상태 파일을 사용하므로, 상태 파일을 안전하게 관리해야 합니다.
- 이 모듈에서 생성된 S3 버킷은 다른 모든 테라폼 모듈의 기반이 되므로, 삭제하거나 변경할 때 주의해야 합니다.
- 버킷을 삭제하기 전에 모든 내용물을 비워야 합니다(force_destroy 설정이 true여도 내용물이 있으면 삭제되지 않을 수 있음).
- 01-common 이후의 모듈은 이 버킷에 상태 파일을 저장하므로, 00-static 모듈을 적용한 후에 다른 모듈을 초기화하고 적용하세요.