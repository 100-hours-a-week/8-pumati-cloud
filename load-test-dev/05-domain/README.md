# Load Test CloudFront Integration

로드테스트 환경의 CloudFront 통합 설정입니다.

## 📋 개요

기존 **chat.goorm-ktb-008.goorm.team** CloudFront Distribution에 백엔드 ALB Origin을 추가하여 프론트엔드와 백엔드를 통합 서비스로 제공합니다.

## 🏗️ 아키텍처

```
사용자 요청
    ↓
CloudFront (chat.goorm-ktb-008.goorm.team)
    ↓
┌─────────────────┬─────────────────┐
│   기본 요청 (/) │   API 요청      │
│   ↓             │   /api/*, /health│
│   S3 Origin     │   ↓             │
│   (프론트엔드)   │   ALB Origin    │
│                 │   (백엔드)       │
└─────────────────┴─────────────────┘
```

## ⚠️ 중요: 기존 CloudFront Import

현재 CloudFront Distribution `E2UUSZ0MG179D8`가 이미 존재하므로, Terraform으로 import해야 합니다.

### 1. CloudFront Import 명령
```bash
cd load-test-dev/05-domain
terraform init

# 기존 CloudFront Distribution Import
terraform import aws_cloudfront_distribution.main E2UUSZ0MG179D8
```

## 🚀 배포 방법

### 1. 사전 요구사항 확인
```bash
# 03-compute 모듈이 먼저 배포되어 있어야 함
cd ../03-compute
terraform output backend_alb_dns

# S3 버킷 존재 확인
aws s3 ls s3://chat.goorm-ktb-008.goorm.team
```

### 2. CloudFront 설정 배포
```bash
cd load-test-dev/05-domain
terraform init
terraform plan
terraform apply
```

### 3. 배포 후 확인
```bash
# 설정된 정보 확인
terraform output

# CloudFront 캐시 무효화 (즉시 반영)
aws cloudfront create-invalidation \
  --distribution-id $(terraform output -raw cloudfront_distribution_id) \
  --paths "/*"
```

## 🔗 라우팅 규칙

### 프론트엔드 (S3 Origin)
- **패턴**: `/*` (기본)
- **대상**: S3 버킷
- **처리**: 
  - `/` → `index.html`
  - `/chat` → `index.html` (SPA 라우팅)
  - `/profile` → `index.html` (SPA 라우팅)
  - 정적 파일 → 직접 서빙

### 백엔드 (ALB Origin)
- **패턴**: `/api/*`
- **대상**: 백엔드 ALB
- **처리**: Express.js API 호출
- **메서드**: GET, POST, PUT, DELETE, PATCH, OPTIONS

### 헬스체크
- **패턴**: `/health`
- **대상**: 백엔드 ALB
- **처리**: 헬스체크 엔드포인트

## 📊 모니터링 및 확인

### 기본 테스트
```bash
# 프론트엔드 접속 테스트
curl -I https://chat.goorm-ktb-008.goorm.team

# 백엔드 API 테스트
curl https://chat.goorm-ktb-008.goorm.team/api/health

# 헬스체크 테스트
curl https://chat.goorm-ktb-008.goorm.team/health
```

### 상세 테스트
```bash
# SPA 라우팅 테스트
curl -I https://chat.goorm-ktb-008.goorm.team/chat-rooms

# API POST 테스트
curl -X POST https://chat.goorm-ktb-008.goorm.team/api/test \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'

# WebSocket 연결 테스트 (브라우저에서)
# const socket = io('https://chat.goorm-ktb-008.goorm.team');
```

## 🛠️ 문제 해결

### 1. CloudFront 캐시 문제
```bash
# 전체 캐시 무효화
aws cloudfront create-invalidation \
  --distribution-id E2UUSZ0MG179D8 \
  --paths "/*"

# API 경로만 무효화
aws cloudfront create-invalidation \
  --distribution-id E2UUSZ0MG179D8 \
  --paths "/api/*"
```

### 2. API 요청이 S3로 가는 경우
**원인**: Cache Behavior 순서 문제
**해결**: 
1. `/api/*` behavior가 기본 behavior보다 우선순위가 높은지 확인
2. Path Pattern이 정확한지 확인

### 3. CORS 문제
```bash
# CORS 헤더 확인
curl -H "Origin: https://chat.goorm-ktb-008.goorm.team" \
     -H "Access-Control-Request-Method: POST" \
     -H "Access-Control-Request-Headers: X-Requested-With" \
     -X OPTIONS \
     https://chat.goorm-ktb-008.goorm.team/api/test
```

### 4. SSL/TLS 문제
- CloudFront는 us-east-1의 ACM 인증서만 사용 가능
- 인증서가 `chat.goorm-ktb-008.goorm.team`에 대해 유효한지 확인

## 📝 설정 상세

### Origins 설정
1. **S3 Origin**
   - Origin Access Control (OAC) 사용
   - S3 버킷 정책으로 CloudFront만 접근 허용
   
2. **ALB Origin**
   - HTTP만 사용 (ALB에서 HTTPS 종료)
   - Connection timeout: 10초
   - Connection attempts: 3회

### Cache Behaviors
1. **기본 Behavior (프론트엔드)**
   - 캐싱 최적화
   - GZIP 압축 활성화
   - SPA 리다이렉트 함수 적용

2. **API Behavior**
   - 캐싱 비활성화
   - 모든 HTTP 메서드 허용
   - Origin 요청 정책 적용

### Security Features
- HTTPS 강제 리다이렉트
- Origin Access Control (OAC)
- TLS 1.2 이상 강제
- 지리적 제한 없음

## 🔄 업데이트 및 유지보수

### CloudFront 설정 변경
```bash
# 설정 변경 후
terraform plan
terraform apply

# 변경사항 즉시 반영
aws cloudfront create-invalidation \
  --distribution-id $(terraform output -raw cloudfront_distribution_id) \
  --paths "/*"
```

### ALB 주소 변경 시
```bash
# compute 모듈에서 ALB 재생성 후
cd load-test-dev/05-domain
terraform refresh
terraform plan
terraform apply
```

## 📞 연락처 및 지원

- **환경**: Load Test
- **관리자**: jacky
- **관련 모듈**: 03-compute (ALB), S3 버킷
- **AWS 리전**: ap-northeast-2 (서울) + us-east-1 (ACM)
- **CloudFront ID**: E2UUSZ0MG179D8 