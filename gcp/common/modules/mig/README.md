# GCP 관리형 인스턴스 그룹(MIG) 모듈

이 모듈은 GPU 워크로드를 위한 관리형 인스턴스 그룹(MIG)을 생성합니다. GPU 유형별 우선순위에 따라 인스턴스를 자동으로 생성하고 관리합니다.

## 주요 기능

- GPU 우선순위 기반 인스턴스 관리 (L4 → T4 → P100)
- GPU 할당량 초과 시 자동으로 다음 우선순위의 GPU로 전환
- 스팟(선점형) 인스턴스 지원으로 비용 최적화
- 상태 확인을 통한 자동 복구 기능

## 고정된 설정 값

모듈에는
다음과 같은 GPU 관련 설정이 하드코딩되어 있습니다:

| 설정 | 값 | 설명 |
|------|-------------|------|
| GPU 유형 | L4, T4, P100 | 우선순위 순서대로 시도 |
| GPU 개수 | 1개 | 각 인스턴스에 연결되는 GPU 개수 |
| 부팅 디스크 이미지 | debian-cloud/debian-11 | 모든 GPU 유형과 호환되는 이미지 |
| 부팅 디스크 크기 | 100GB | GPU 워크로드에 최적화된 용량 |
| 부팅 디스크 유형 | pd-ssd | 성능을 위한 SSD 스토리지 |

## 사용 방법

```hcl
module "gpu_mig" {
  source = "../modules/mig"

  # [필수] 기본 설정
  instance_name        = "gpu-worker"
  machine_type         = "n1-standard-4"
  project_id           = "my-project"
  region               = "asia-northeast3"
  
  # 추가 설정 (모두 지정 필요)
  spot                 = true
  network              = "default"
  service_account_email = "my-service-account@my-project.iam.gserviceaccount.com"
  service_account_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  
  # 시작 스크립트 (선택적)
  startup_script       = <<-EOT
    #!/bin/bash
    apt-get update
    apt-get install -y docker.io
    # 추가 설치 명령...
  EOT
  
  # 태그 및 라벨 (선택적)
  tags                 = ["gpu", "worker"]
  labels               = {
    environment = "production"
    application = "ai-inference"
  }
  
  # 메타데이터 (선택적)
  additional_metadata  = {
    "enable-oslogin" = "TRUE"
  }
}
```

## 입력 변수

| 이름 | 설명 | 타입 | 권장값 | 필수 |
|------|-------------|------|---------|:--------:|
| instance_name | 인스턴스 기본 이름 | `string` | 프로젝트 내에서 고유한 이름 | ✓ |
| machine_type | 인스턴스 머신 타입 | `string` | `n1-standard-4` | ✓ |
| project_id | GCP 프로젝트 ID | `string` | 유효한 GCP 프로젝트 ID | ✓ |
| region | 인스턴스가 배포될 GCP 리전 | `string` | `asia-northeast3` | ✓ |
| zone | 인스턴스가 배포될 GCP 영역 | `string` | 비워두면 리전 내에서 자동 선택 | |
| spot | 스팟(선점형) 인스턴스 사용 여부 | `bool` | `true` (비용 최적화) | ✓ |
| network | 연결할 네트워크 | `string` | `default` 또는 기존 VPC 네트워크 | ✓ |
| startup_script | 시작 스크립트 | `string` | 필요한 도구 설치 스크립트 | |
| service_account_email | 서비스 계정 이메일 | `string` | 비워두면 프로젝트 기본값 사용 | |
| service_account_scopes | 서비스 계정 권한 범위 | `list(string)` | `["https://www.googleapis.com/auth/cloud-platform"]` | ✓ |
| tags | 네트워크 태그 | `list(string)` | `["gpu", "worker"]` 등 용도에 맞게 지정 | |
| labels | 리소스 라벨 | `map(string)` | `{"environment"="prod"}` | |
| additional_metadata | 추가 메타데이터 | `map(string)` | `{"enable-oslogin"="TRUE"}` | |

**참고**: 필수 표시가 없는 변수도 모듈에서 기본값을 제공하지 않으므로 직접 값을 지정해야 합니다.

## 출력 값

| 이름 | 설명 |
|------|-------------|
| instance_group | 생성된 인스턴스 그룹 ID |
| instance_group_manager_id | 생성된 인스턴스 그룹 매니저 ID |
| instance_group_manager_self_link | 생성된 인스턴스 그룹 매니저 self_link |
| available_templates | 사용 가능한 템플릿 정보 (L4, T4, P100) |
| health_check_self_link | 인스턴스 자동 복구 상태 확인 self_link |

## GPU 우선순위 구현 방식

이 모듈은 다음 방식으로 GPU 우선순위를 구현합니다:

1. **3가지 인스턴스 템플릿 생성**:
   - L4 GPU 템플릿: 최우선 사용
   - T4 GPU 템플릿: L4 할당량 부족 시 사용
   - P100 GPU 템플릿: L4, T4 모두 사용할 수 없을 때 사용

2. **MIG 버전 구성**:
   - 첫 번째 버전은 L4로 1개 인스턴스 설정 (target_size.fixed = 1)
   - 다른 버전들은 0개 인스턴스로 설정 (target_size.fixed = 0)
   - MIG 전체 target_size는 1로 설정

3. **자동 대체 메커니즘**:
   - L4 GPU를 할당할 수 없으면 Terraform이 오류를 반환하는 대신 다음 버전을 시도합니다
   - PROACTIVE 업데이트 정책과 SUBSTITUTE 대체 방법 사용
   - lifecycle 설정으로 자동 확장 관련 변경 무시

## 중요 주의사항

1. **사전 준비사항**:
   - 프로젝트에 필요한 GPU 할당량이 있는지 확인 필요
   - 적절한 네트워크와 방화벽 규칙이 구성되어 있어야 함
   - 서비스 계정에 필요한 권한이 부여되어 있어야 함

2. **GPU 가용성**:
   - 모든 리전에서 모든 GPU 유형을 사용할 수 있는 것은 아님
   - 선택한 리전에서 지정된 GPU 유형이 지원되는지 확인 필요

3. **실제 작동 방식**:
   - 첫 배포 시 L4 GPU로 시도하고, 할당량 초과 시 T4, P100 순으로 시도
   - 자동 복구 또는 업데이트 시에도 동일한 우선순위 적용
   - 리소스 생성은 비동기식으로 진행되므로 실패하면 다음 버전으로 넘어가는데 몇 분 소요될 수 있음

4. **테스트 필요**:
   - 실제 환경에서는 GPU 할당량 상황에 따라 다르게 작동할 수 있음
   - 프로덕션 환경 적용 전 테스트 환경에서 검증 권장 