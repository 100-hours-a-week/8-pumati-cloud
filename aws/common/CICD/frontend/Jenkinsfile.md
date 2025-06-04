# Jenkins Pipeline 가이드

## 환경 변수 설정

## 파이프라인 스테이지

### 1. Set Branch & Cron Trigger

**목적**: 브랜치 확인 및 자동 실행 스케줄 설정

* 브랜치명 추출 및 환경 설정
* main 브랜치: 매일 9시 자동 실행
* dev 브랜치: 자동 실행 없음
* 지원하지 않는 브랜치: 빌드 중단

### 2. Notify Before Start

**목적**: 빌드 시작 알림

* Discord 웹훅을 통한 알림 전송
* 서비스명과 브랜치 정보 포함
* 실패해도 파이프라인은 계속 진행

### 3. Checkout

**목적**: 소스 코드 체크아웃

* Git 저장소에서 코드 가져오기
* Jenkins Credentials 사용 (GITHUB\_TOKEN\_UWP)

### 4. Set Environment by Branch

**목적**: 브랜치별 환경 변수 설정

* main 브랜치:
  * ENV\_LABEL: 'prod'
  * FE\_PRIVATE\_IP: '10.3.0.228'
  * ECR\_REPO: 'pumati-prod-frontend-ecr'
* dev 브랜치:
  * ENV\_LABEL: 'dev'
  * FE\_PRIVATE\_IP: '10.1.0.253'
  * ECR\_REPO: 'pumati-dev-frontend-ecr'
* 공통 설정:
  * TIMESTAMP + GIT HASH를 포함한 혼합형 TAG 생성
  * IMAGE\_TAG: 'frontend-dev-42-20250602-145910-a3f12c9'
  * ECR\_IMAGE: AWS ECR 이미지 전체 경로

### 5. Fetch .env from AWS Secrets Manager

**목적**: 환경 변수 파일 가져오기

* AWS Secrets Manager에서 .env 파일 내용 가져오기
* Jenkins 작업 디렉토리에 저장
* 파일 권한 설정 (chmod 600)
* 실패 시 빌드 중단 처리

### 6. Authorize Docker to ECR

**목적**: AWS ECR 인증

* `aws ecr get-login-password`를 사용한 인증 토큰 획득
* Docker에 로그인하여 이미지 푸시 가능 상태로 전환

### 7. Docker Build & Push to ECR

**목적**: Docker 이미지 빌드 및 ECR 푸시

* .env에서 필요한 key만 export
* build-arg로 Dockerfile에 환경변수 주입
* 혼합형 태그명으로 이미지 빌드 및 ECR에 푸시

### 8. Save Docker Image & Upload to S3

**목적**: 빌드된 Docker 이미지를 tar로 저장 및 업로드

* 파일명: `${SERVICE_NAME}-${ENV_LABEL}-${BUILD_NUMBER}-${TIMESTAMP}-${GIT_HASH}.tar`
* 이미지 저장: `docker save`
* S3 업로드: `aws s3 cp`로 `/CI/{ENV}/{SERVICE}/{tar}`에 업로드
* 예시:
  ```
  s3://s3-pumati-common-storage/CI/prod/frontend/frontend-prod-42-20250602-145910-a3f12c9.tar
  ```
  * `pumati-common-storage`: 프로젝트 공용 S3 버킷
  * `CI/prod/frontend`: 환경(prod) 및 서비스(frontend) 구분 경로
  * `frontend-prod-42-20250602-145910-a3f12c9.tar`:
    * `frontend-prod`: 서비스명과 환경
    * `42`: Jenkins 빌드 번호
    * `20250602-145910`: 빌드 시각 (KST, yyyymmdd-HHmmss)
    * `a3f12c9`: Git 커밋 해시 (짧은 형태)

### 9. Deploy to Frontend EC2 via SSH

**목적**: EC2에 프론트엔드 배포

* SSH를 통해 EC2에 접속
* 기존 컨테이너 중지 및 제거
* ECR 인증 및 이미지 Pull
* 새 컨테이너 실행 및 PID 출력
* 사용하지 않는 이미지 정리

## 주의사항

1. **보안**
   * 민감한 정보는 Jenkins Credentials 사용
   * .env 파일 권한 제한 (chmod 600)
   * AWS 자격 증명은 IAM Role 또는 Credential로 안전하게 관리

2. **에러 처리**
   * 각 스테이지에서 try-catch 혹은 set -e로 중단 처리
   * 알림 실패는 파이프라인 중단 없이 로깅만

3. **최적화**
   * .dockerignore로 빌드 컨텍스트 최소화
   * 멀티 스테이지 Docker 빌드로 이미지 크기 최소화
   * 빌드 캐시 활용 위해 의존성 먼저 COPY 및 install

## 실행 환경 요구사항

1. **Jenkins 플러그인**
   * Docker Pipeline
   * AWS Pipeline (또는 AWS CLI 접근)
   * Discord Notifier

2. **AWS 설정**
   * ECR 저장소 (미리 생성 또는 자동 생성 로직 추가 가능)
   * Secrets Manager에 `.env` 형식으로 시크릿 저장
   * S3 버킷 권한
   * IAM Role에 다음 권한:
     * `secretsmanager:GetSecretValue`
     * `ecr:*Upload*`, `ecr:PutImage`, `ecr:GetAuthorizationToken`
     * `s3:PutObject`, `s3:GetObject`

3. **Jenkins Credentials**
   * GITHUB\_TOKEN\_UWP: Git checkout용 Personal Access Token
   * Discord-Webhook: Discord 메시지 전송용 URL
   * (선택) AWS 자격 증명: 액세스 키 & 시크릿 또는 IAM Role
