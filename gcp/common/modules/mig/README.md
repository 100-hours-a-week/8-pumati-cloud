# GCP 관리형 인스턴스 그룹(MIG) 모듈

GPU 스팟 인스턴스를 관리형 인스턴스 그룹으로 배포하기 위한 테라폼 모듈입니다.

## 주요 기능

- **존 간 자동 전환**: 여러 존에 걸쳐 GPU 스팟 인스턴스 배포
- **스팟 인스턴스 자동 복구**: 회수된 스팟 인스턴스 자동 재생성
- **헬스 체크 및 자동 복구**: 비정상 인스턴스 감지 및 자동 교체
- **최적화된 GPU 설정**: L4, T4, P100 등 다양한 GPU 유형 지원
- **비용 최적화**: 스팟 인스턴스로 비용 절감

## 목표 시나리오

이 모듈은 다음과 같은 사용 사례에 최적화되어 있습니다:

1. **L4 GPU 스팟 인스턴스** 실행 (비용 최적화)
2. 스팟 인스턴스 회수 시 **자동으로 새 인스턴스 생성**
3. 특정 존에서 GPU 할당량 부족 시 **다른 존으로 자동 전환**
4. 최대 1개의 GPU 인스턴스만 실행 (GPU 할당량 1)

## 사용 방법

### 기본 사용법 (단일 GPU 타입)

```hcl
module "l4_gpu_mig" {
  source = "../../common/modules/mig"

  # 프로젝트 및 위치 설정
  project_id = "my-project-id"
  region     = "asia-northeast3"
  zones      = ["asia-northeast3-a", "asia-northeast3-b"]
  
  # 인스턴스 기본 설정
  instance_name = "l4-gpu-spot"
  machine_type  = "g2-standard-4"
  spot          = true
  
  # 디스크 설정
  source_image  = "deeplearning-platform-release/tf-latest-gpu"
  disk_size_gb  = 100
  disk_type     = "pd-ssd"
  
  # GPU 설정
  gpu_type      = "nvidia-l4"
  gpu_count     = 1
  
  # 네트워크 설정
  network       = "default"
  
  # 서비스 계정 설정
  service_account_email  = ""
  service_account_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  
  # 스크립트 및 메타데이터
  startup_script    = file("${path.module}/startup-script.sh")
  additional_metadata = {
    purpose = "ai-inference"
  }
  
  # 태그 및 라벨
  tags    = ["gpu", "spot"]
  labels  = {
    environment = "dev"
    managed-by  = "terraform"
  }
  
  # MIG 설정
  target_size = 1  # 인스턴스 1개 시작
  
  # 기타 설정
  http_port  = 8000
  https_port = 8443
  
  # 헬스 체크 설정
  health_check_port   = 22
  initial_delay_sec   = 300
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3
  
  # 업데이트 정책
  update_type                   = "PROACTIVE"
  instance_redistribution_type  = "NONE"
  minimal_action                = "REPLACE"
  most_disruptive_allowed_action = "REPLACE"
  max_surge_fixed               = 0
  max_unavailable_fixed         = 1
  wait_for_instances            = true
}
```

### GPU 타입 자동 전환을 위한 여러 MIG 배포

L4 → T4 → P100 순으로 자동 전환하려면, 각 GPU 타입마다 별도의 MIG를 생성하고 외부 자동화 스크립트를 사용해야 합니다.

```hcl
# L4 GPU MIG - 최우선 사용
module "l4_gpu_mig" {
  source        = "../../common/modules/mig"
  instance_name = "l4-gpu-spot"
  gpu_type      = "nvidia-l4"
  machine_type  = "g2-standard-4"
  target_size   = 1  # 초기에 1개 실행
  # 다른 설정...
}

# T4 GPU MIG - L4 할당량 부족 시 사용
module "t4_gpu_mig" {
  source        = "../../common/modules/mig"
  instance_name = "t4-gpu-spot"
  gpu_type      = "nvidia-tesla-t4"
  machine_type  = "n1-standard-4"
  target_size   = 0  # 초기에 0개 실행
  # 다른 설정...
}

# P100 GPU MIG - L4/T4 모두 할당량 부족 시 사용
module "p100_gpu_mig" {
  source        = "../../common/modules/mig"
  instance_name = "p100-gpu-spot"
  gpu_type      = "nvidia-tesla-p100"
  machine_type  = "n1-standard-4"
  target_size   = 0  # 초기에 0개 실행
  # 다른 설정...
}
```

## 필수 변수

| 변수 이름 | 설명 |
|----------|------|
| project_id | GCP 프로젝트 ID |
| region | 인스턴스 배포 리전 |
| zones | 인스턴스 배포 가능 존 목록 |
| instance_name | 인스턴스 기본 이름 |
| machine_type | 머신 타입 |
| spot | 스팟 인스턴스 사용 여부 |
| source_image | 부팅 디스크 이미지 |
| disk_size_gb | 디스크 크기(GB) |
| disk_type | 디스크 유형 |
| gpu_type | GPU 유형 |
| gpu_count | GPU 개수 |
| network | 네트워크 이름 |
| service_account_email | 서비스 계정 이메일 |
| service_account_scopes | 서비스 계정 권한 범위 |
| startup_script | 시작 스크립트 |

## 출력 값

| 출력 이름 | 설명 |
|----------|------|
| instance_group | 인스턴스 그룹 ID |
| instance_group_manager_id | 인스턴스 그룹 매니저 ID |
| instance_group_manager_self_link | 인스턴스 그룹 매니저 self_link |
| instance_template_id | 인스턴스 템플릿 ID |
| instance_template_self_link | 인스턴스 템플릿 self_link |
| health_check_self_link | 헬스 체크 self_link |
| mig_name | MIG 이름 |
| gpu_info | GPU 유형 및 개수 정보 |

## GPU 유형 자동 전환 스크립트 예시

GPU 유형 간 자동 전환을 위한 스크립트 예시입니다. 이 스크립트는 Cloud Functions, Cloud Scheduler와 함께 사용할 수 있습니다.

```python
#!/usr/bin/env python3
import subprocess
import time

PROJECT = "your-project-id"
REGION = "asia-northeast3"
MIG_L4 = "l4-gpu-spot-mig"
MIG_T4 = "t4-gpu-spot-mig"
MIG_P100 = "p100-gpu-spot-mig"

def check_mig_status(mig_name):
    """MIG에 RUNNING 상태의 인스턴스가 있는지 확인"""
    cmd = f"gcloud compute instance-groups managed list-instances {mig_name} \
            --region {REGION} --project {PROJECT} --format='value(status)'"
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return "RUNNING" in result.stdout

def resize_mig(mig_name, size):
    """MIG 크기 조절"""
    cmd = f"gcloud compute instance-groups managed resize {mig_name} \
            --size={size} --region={REGION} --project={PROJECT}"
    subprocess.run(cmd, shell=True)

def main():
    # 모든 MIG를 0으로 리셋 (초기화)
    print("모든 MIG 초기화 중...")
    resize_mig(MIG_L4, 0)
    resize_mig(MIG_T4, 0)
    resize_mig(MIG_P100, 0)
    time.sleep(30)  # 초기화 완료 대기
    
    # L4 시도
    print("L4 GPU 시도 중...")
    resize_mig(MIG_L4, 1)
    time.sleep(180)  # 3분 대기
    
    # L4 확인
    if check_mig_status(MIG_L4):
        print("✅ L4 GPU 인스턴스 생성 성공!")
        return
    
    # L4 실패 → T4 시도
    print("❌ L4 GPU 실패, T4 시도 중...")
    resize_mig(MIG_L4, 0)  # 확실히 0으로
    resize_mig(MIG_T4, 1)
    time.sleep(180)  # 3분 대기
    
    # T4 확인
    if check_mig_status(MIG_T4):
        print("✅ T4 GPU 인스턴스 생성 성공!")
        return
    
    # T4 실패 → P100 시도
    print("❌ T4 GPU 실패, P100 시도 중...")
    resize_mig(MIG_T4, 0)  # 확실히 0으로
    resize_mig(MIG_P100, 1)
    time.sleep(180)  # 3분 대기
    
    # P100 확인
    if check_mig_status(MIG_P100):
        print("✅ P100 GPU 인스턴스 생성 성공!")
    else:
        print("❌ 모든 GPU 유형 시도 실패! 관리자 확인 필요")

if __name__ == "__main__":
    main()
```

## 참고 사항

1. **존 간 자동 전환**: `distribution_policy_zones`에 여러 존을 지정하면 GCP가 자동으로 GPU가 가용한 존에 인스턴스를 배치합니다.

2. **자동 복구**: 스팟 인스턴스가 회수되면 MIG는 자동으로 새 인스턴스를 생성합니다.

3. **GPU 유형 자동 전환**: GCP MIG는 GPU 유형 간 자동 전환을 직접 지원하지 않습니다. 이를 위해서는 앞서 제시한 것과 같은 외부 자동화 스크립트가 필요합니다.

4. **모든 설정 변수화**: 모든 주요 설정이 변수로 제공되므로 다양한 상황에 맞게 커스터마이징할 수 있습니다.

5. **최적 머신 타입**: 
   - L4 GPU: `g2-standard-4` 이상 권장
   - T4/P100 GPU: `n1-standard-4` 이상 권장
