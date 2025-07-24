# ASG 인스턴스 깔끔한 교체 가이드

## 현재 상태
- 모든 ASG `desired_capacity = 0` 
- 모든 ASG `min_size = 0`
- 기존 인스턴스들이 모두 종료됨

## 복원 방법

### 1단계: variables.tf 수정
```bash
# load-test-dev/03-compute/variables.tf에서 다음 값들을 변경:

variable "backend_asg_desired" {
  default = 5  # 0에서 5로 변경
}

variable "frontend_asg_desired" {
  default = 5  # 0에서 5로 변경
}

variable "backend_asg_min" {
  default = 1  # 0에서 1로 변경
}

variable "frontend_asg_min" {
  default = 1  # 0에서 1로 변경
}
```

### 2단계: Terraform 적용
```bash
cd load-test-dev/03-compute
terraform apply
```

### 3단계: 결과 확인
```bash
# 새로운 인스턴스들이 모두 "backend", "frontend" 이름으로 생성됨
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=backend,frontend" \
          "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value|[0],InstanceId,PublicIpAddress]' \
  --output table
```

## 예상 결과
- ✅ 모든 인스턴스 이름이 `backend`, `frontend`로 통일
- ✅ 이전 `pumati-load-test-*` 이름의 인스턴스들 모두 제거
- ✅ SSH 접속 가능 (22번 포트 외부 오픈)
- ✅ 새로운 Launch Template 적용됨

## 빠른 복원 명령어
```bash
# variables.tf 복원 (수동으로 편집기에서)
# 또는 sed 명령어로:
sed -i 's/default     = 0  # 임시로 0으로 설정하여 모든 인스턴스 종료/default     = 5/' load-test-dev/03-compute/variables.tf
sed -i 's/default     = 0  # 임시로 0으로 설정/default     = 1/' load-test-dev/03-compute/variables.tf

# Terraform 적용
terraform apply -auto-approve
``` 