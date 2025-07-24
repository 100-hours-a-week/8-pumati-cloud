# Load Test Compute Infrastructure

로드테스트용 Compute 인프라 구성입니다.

## 아키텍처 개요

### 선택된 구성: ALB → EC2
```
Internet → ALB → Target Groups → Auto Scaling Groups → EC2 Instances
```

### NLB를 사용하지 않는 이유

**NLB + ALB 조합의 문제점:**
- ❌ **불필요한 홉**: 인터넷 → NLB → ALB → EC2 (3단계)
- ❌ **비용 증가**: NLB + ALB 이중 과금 
- ❌ **레이턴시 증가**: 로드밸런서 2단계 통과
- ❌ **복잡성 증가**: 관리 포인트 증가

**ALB 단독 사용의 장점:**
- ✅ **단순한 경로**: 인터넷 → ALB → EC2 (2단계)
- ✅ **비용 절약**: ALB만 과금
- ✅ **낮은 레이턴시**: 홉 수 최소화
- ✅ **HTTP 최적화**: 로드테스트에 적합한 기능들
- ✅ **관리 단순화**: 하나의 로드밸런서만 관리

## 구성 요소

### 1. Application Load Balancer (ALB)
- **백엔드 ALB**: 백엔드 API 트래픽 처리
- **프론트엔드 ALB**: 프론트엔드 웹 트래픽 처리
- **헬스체크**: HTTP 기반 정교한 헬스체크
- **경로 기반 라우팅**: 필요시 다양한 라우팅 규칙 적용 가능

### 2. Auto Scaling Groups
- **백엔드 ASG**: 기본 5개, 최대 15개 인스턴스
- **프론트엔드 ASG**: 기본 5개, 최대 15개 인스턴스
- **탄력적 확장**: 부하에 따른 자동 스케일링
- **헬스체크**: ELB 기반 인스턴스 교체

### 3. 보안 그룹
- **계층별 분리**: 인스턴스용 / ALB용 보안 그룹
- **최소 권한**: 필요한 포트만 개방
- **VPC 내부 통신**: SSH는 VPC 내부에서만

## 성능 특성

### ALB 성능 지표
- **처리량**: 수천~수만 RPS 처리 가능
- **레이턴시**: <100ms (일반적)
- **연결 처리**: HTTP/2, WebSocket 지원
- **헬스체크**: HTTP 기반 정교한 감지

### 확장성
- **수평 확장**: ASG를 통한 인스턴스 증가
- **빠른 반응**: ALB는 자동으로 새 인스턴스 감지
- **부하 분산**: 가중치 기반 정교한 분산

## 배포 및 관리

### 초기 배포
```bash
cd load-test-dev/03-compute
terraform init
terraform plan
terraform apply
```

### 실시간 확장
```bash
# 백엔드 10개로 확장
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name ktb-load-test-dev-backend-asg \
  --desired-capacity 10

# 프론트엔드 10개로 확장
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name ktb-load-test-dev-frontend-asg \
  --desired-capacity 10
```

### 대회 당일 긴급 확장
```bash
# Terraform 변수로 한번에 확장
terraform apply \
  -var='backend_asg_desired=15' \
  -var='frontend_asg_desired=15' \
  -var='backend_asg_max=20' \
  -var='frontend_asg_max=20'
```

## 모니터링

### CloudWatch 메트릭
- **네임스페이스**: LoadTest/Backend, LoadTest/Frontend  
- **주요 메트릭**: CPU, 메모리, 네트워크, 연결 수
- **로그 그룹**: 애플리케이션 로그 실시간 수집

### ALB 메트릭
- **요청 수**: RequestCount
- **응답 시간**: TargetResponseTime  
- **에러율**: HTTPCode_Target_4XX_Count, 5XX_Count
- **활성 연결**: ActiveConnectionCount

## NLB 활성화 (선택사항)

극한의 성능이 필요한 경우에만 NLB를 활성화할 수 있습니다:

```bash
# variables.tf에서 enable_nlb = true로 변경 후
terraform apply
```

**NLB 활성화 시나리오:**
- 초당 10만+ 요청 필요
- TCP 레벨 최적화 필요  
- 정적 IP 필요
- 극도로 낮은 레이턴시 필요

하지만 대부분의 로드테스트에서는 ALB만으로도 충분합니다.

## 리소스 사용량

### 현재 구성 (ALB 단독)
- **EC2 인스턴스**: 10개 (백엔드 5 + 프론트엔드 5)
- **로드밸런서**: 2개 (ALB 백엔드 + ALB 프론트엔드)
- **총 t3.small 사용량**: 10/30 (33.3%)

### 최대 확장 시
- **EC2 인스턴스**: 30개 (백엔드 15 + 프론트엔드 15)  
- **총 t3.small 사용량**: 30/30 (100%)

## 비용 최적화

ALB 단독 사용으로 다음과 같은 비용 절약:
- **NLB 비용 제거**: 월 $16-20 절약
- **데이터 처리 비용**: NLB 추가 홉 제거
- **관리 복잡성**: 운영 비용 감소

로드테스트는 단기간 사용이므로 단순하고 효율적인 구성이 최적입니다. 

## 🔍 **배포 후 확인 방법**

### 1. **인스턴스 목록 확인**
```bash
# 백엔드 인스턴스 확인
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=backend" \
          "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress,PrivateIpAddress,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# 프론트엔드 인스턴스 확인  
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=frontend" \
          "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress,PrivateIpAddress,Tags[?Key==`Name`].Value|[0]]' \
  --output table
```

### 2. **SSH 접속**
```bash
# 백엔드 인스턴스 접속
ssh -i ~/.ssh/8-ktb-chat-keypair.pem ubuntu@<BACKEND_PUBLIC_IP>

# 프론트엔드 인스턴스 접속
ssh -i ~/.ssh/8-ktb-chat-keypair.pem ubuntu@<FRONTEND_PUBLIC_IP>
```

### 3. **애플리케이션 상태 확인**
```bash
# SSH 접속 후 확인
pm2 status                    # PM2 프로세스 상태
pm2 logs                      # 애플리케이션 로그
curl localhost:3000/health    # 헬스체크 (백엔드)
curl localhost:3000/          # 프론트엔드 페이지
```

### 4. **ALB 엔드포인트 테스트**
```bash
# Terraform 출력에서 URL 확인
terraform output | grep -E "(backend_url|frontend_url)"

# 백엔드 API 테스트
curl http://<BACKEND_ALB_DNS>/health

# 프론트엔드 페이지 테스트
curl http://<FRONTEND_ALB_DNS>/
```

### 5. **Auto Scaling Group 상태 확인**
```bash
# ASG 상태 확인
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names \
    "pumati-load-test-backend-asg" \
    "pumati-load-test-frontend-asg" \
  --query 'AutoScalingGroups[*].[AutoScalingGroupName,DesiredCapacity,MinSize,MaxSize,Instances[0].HealthStatus]' \
  --output table
```

## 인스턴스 명명 규칙

**인스턴스 이름:**
- 백엔드: `backend` (AWS가 자동으로 번호 부여)
- 프론트엔드: `frontend` (AWS가 자동으로 번호 부여)

**실제 인스턴스 이름 예시:**
```
backend (i-1234567890abcdef0)
backend (i-0fedcba0987654321)
frontend (i-abcdef1234567890)
frontend (i-fedcba0987654321)
``` 