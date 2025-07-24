# Load Test Backend Infrastructure

로드테스트용 백엔드 인프라 구성입니다. (프론트엔드는 S3로 별도 구성)

## 아키텍처 개요

### 현재 구성: ALB → 고정 인스턴스 + 오토 힐링
```
Internet → ALB → Target Group → 고정 5개 EC2 인스턴스 (오토 힐링)
```

### 설계 원칙
- ✅ **단순성**: 복잡한 오토 스케일링 제거
- ✅ **안정성**: 고정된 수의 인스턴스로 예측 가능한 성능
- ✅ **신뢰성**: 오토 힐링으로 인스턴스 장애 시 자동 교체
- ✅ **비용 효율**: 불필요한 스케일링 방지

## 구성 요소

### 1. Application Load Balancer (ALB)
- **백엔드 ALB**: 백엔드 API 트래픽 처리
- **헬스체크**: HTTP 기반 정교한 헬스체크 (`/health`)
- **고가용성**: 여러 AZ에 분산된 인스턴스로 트래픽 분산

### 2. 고정 인스턴스 + 오토 힐링
- **인스턴스 수**: 고정 5개 (min=max=desired=5)
- **오토 힐링**: 인스턴스 장애 시 자동 교체
- **스케일링 없음**: 예측 가능한 성능과 비용
- **헬스체크**: ELB 기반 인스턴스 상태 감지

### 3. 보안 그룹
- **백엔드 인스턴스**: ALB에서 3000번 포트, SSH 22번 포트
- **백엔드 ALB**: 인터넷에서 80번, 443번 포트
- **최소 권한**: 필요한 포트만 개방

## 성능 특성

### 처리 용량
- **고정 5개 인스턴스**: 예측 가능한 성능
- **t3.small**: 각 인스턴스당 적절한 처리 능력
- **ALB**: 수천~수만 RPS 처리 가능
- **오토 힐링**: 장애 시 자동 복구 (5분 이내)

## 배포 및 관리

### 초기 배포
```bash
cd load-test-dev/03-compute
terraform init
terraform plan
terraform apply
```

### 인스턴스 수 변경 (필요시)
```bash
# variables.tf에서 backend_instance_count 변경 후
terraform apply -var='backend_instance_count=10'
```

### 인스턴스 교체 (Rolling Update)
```bash
# Launch Template 업데이트 후 Rolling 교체
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name pumati-load-test-backend-asg \
  --preferences MinHealthyPercentage=80
```

## 모니터링

### CloudWatch 메트릭
- **네임스페이스**: LoadTest/Backend
- **주요 메트릭**: CPU, 메모리, 네트워크, 디스크
- **로그 그룹**: `/aws/ec2/pumati-load-test-backend`

### ALB 메트릭
- **요청 수**: RequestCount
- **응답 시간**: TargetResponseTime
- **에러율**: HTTPCode_Target_4XX_Count, 5XX_Count
- **활성 연결**: ActiveConnectionCount

### 오토 힐링 모니터링
- **ASG 이벤트**: CloudWatch Events를 통한 인스턴스 교체 알림
- **헬스체크**: Target Group의 Healthy/Unhealthy 상태
- **그레이스 피리어드**: 5분 (300초)

## 오토 힐링 작동 원리

### 1. 헬스체크 실패 감지
```
ALB Target Group → 인스턴스 `/health` 호출
↓ (2회 연속 실패)
Unhealthy 상태로 마킹
```

### 2. ASG 오토 힐링 발동
```
ASG → Unhealthy 인스턴스 감지
↓ (5분 그레이스 피리어드 후)
기존 인스턴스 종료 + 새 인스턴스 생성
```

### 3. 복구 과정
```
새 인스턴스 부팅 → User Data 실행 → 애플리케이션 시작
↓ (헬스체크 통과 후)
ALB Target Group에 Healthy 상태로 등록
```

## 리소스 사용량

### 현재 구성
- **EC2 인스턴스**: 5개 (t3.small)
- **로드밸런서**: 1개 (ALB)
- **오토 스케일링**: 제거 (고정 인스턴스)

### 비용 최적화
- **스케일링 오버헤드 제거**: 불필요한 인스턴스 생성/제거 없음
- **예측 가능한 비용**: 고정된 인스턴스 수
- **단순한 관리**: 복잡한 스케일링 정책 불필요

## 배포 후 확인 방법

### 1. 인스턴스 상태 확인
```bash
# 백엔드 인스턴스 확인
aws ec2 describe-instances \
  --filters "Name=tag:Service,Values=Backend" \
          "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value|[0],InstanceId,PublicIpAddress,PrivateIpAddress]' \
  --output table
```

### 2. ASG 상태 확인
```bash
# Auto Scaling Group 상태
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "pumati-load-test-backend-asg" \
  --query 'AutoScalingGroups[*].[AutoScalingGroupName,DesiredCapacity,MinSize,MaxSize,Instances[].HealthStatus]' \
  --output table
```

### 3. ALB Target 상태 확인
```bash
# Target Group의 인스턴스 헬스 상태
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw backend_target_group_arn)
```

### 4. 백엔드 API 테스트
```bash
# Terraform 출력에서 URL 확인
BACKEND_URL=$(terraform output -raw backend_url)

# 헬스체크 테스트
curl ${BACKEND_URL}/health

# API 테스트
curl ${BACKEND_URL}/api/test
```

### 5. SSH 접속 및 로그 확인
```bash
# 인스턴스 접속
ssh -i ~/.ssh/8-ktb-chat-keypair.pem ubuntu@<PUBLIC_IP>

# 애플리케이션 상태 확인
sudo pm2 status
sudo pm2 logs
sudo systemctl status cloudwatch-agent
```

## 장애 시나리오 및 대응

### 인스턴스 장애
- **감지**: ALB 헬스체크 실패 (2회 연속)
- **대응**: ASG에서 자동으로 새 인스턴스 생성
- **복구 시간**: 약 5-10분

### ALB 장애
- **감지**: 외부 모니터링 도구 필요
- **대응**: AWS에서 자동 복구 (Multi-AZ)
- **복구 시간**: 일반적으로 수 분 이내

### 대량 트래픽 처리
- **현재**: 고정 5개 인스턴스로 처리
- **필요시**: `backend_instance_count` 변수 변경하여 인스턴스 수 증가
- **권장**: 로드테스트 전 적절한 인스턴스 수 설정

## 프론트엔드 관련 참고사항

프론트엔드는 **S3 + CloudFront**로 별도 구성됩니다:
- **정적 파일**: S3에 호스팅
- **CDN**: CloudFront로 전세계 배포
- **API 연동**: 이 백엔드 ALB URL 사용

백엔드 URL은 프론트엔드 빌드 시 환경변수로 설정됩니다. 