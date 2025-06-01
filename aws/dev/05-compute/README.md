compute 모듈 apply 전 필수 확인

- 백엔드 환경 변수에서 DB 호스트 주소 올바르게 되었는지 확인(mysql 인스턴스의 내부 IP)








# 05-compute 모듈 배포 및 테스트 가이드

이 문서는 05-compute 모듈 배포 후 서비스가 정상적으로 동작하는지 테스트하는 방법을 안내합니다.

## 1. 모듈 배포하기

```bash
# 작업 디렉토리로 이동
cd aws/dev/05-compute

# Terraform 초기화
terraform init

# 배포 계획 확인
terraform plan

# 리소스 배포
terraform apply
```

## 2. 배포 결과 확인하기

### 2.1 AWS 콘솔에서 확인

- **EC2 인스턴스**: AWS 콘솔 > EC2 > 인스턴스에서 프론트엔드/백엔드 인스턴스가 정상적으로 실행 중인지 확인
- **ALB**: AWS 콘솔 > EC2 > 로드 밸런서에서 ALB 상태 확인
- **타겟 그룹**: AWS 콘솔 > EC2 > 대상 그룹에서 인스턴스 상태가 "정상"인지 확인
- **Auto Scaling 그룹**: AWS 콘솔 > EC2 > Auto Scaling 그룹에서 용량이 원하는 값과 일치하는지 확인

### 2.2 도메인 연결 확인

```bash
# 도메인 DNS 레코드가 ALB를 가리키는지 확인
dig dev.tebutebu.com

# HTTPS 리다이렉트 확인
curl -I http://dev.tebutebu.com
```

## 3. 프론트엔드 테스트

### 3.1 웹 접근성 테스트

1. 웹 브라우저에서 `https://dev.tebutebu.com` 접속
2. 웹사이트가 정상적으로 로드되는지 확인
3. 페이지 이동 및 기본 기능 테스트

### 3.2 프론트엔드 인스턴스 상태 확인

```bash
# 프론트엔드 인스턴스 ID 확인
aws ec2 describe-instances --filters "Name=tag:Name,Values=pumati-dev-frontend" --query "Reservations[].Instances[].InstanceId" --output text

# 프론트엔드 인스턴스에 SSH 접속
ssh -i "pumati-full-master.pem" ubuntu@{프론트엔드_인스턴스_IP}

# 필수 서비스 실행 확인
systemctl status nginx
ps aux | grep node
ps aux | grep pnpm

# 포트 리스닝 확인
sudo ss -tulpn | grep ':3000'
sudo ss -tulpn | grep ':80'

# 프론트엔드 환경 변수 확인
ls -la /home/ubuntu/.env
head -n 5 /home/ubuntu/8-pumati-fe/.env

# 프론트엔드 로그 확인
tail -f /var/log/frontend-deploy.log          # 배포 로그
tail -f /home/ubuntu/8-pumati-fe/pnpm.log     # 애플리케이션 로그
tail -f /var/log/nginx/error.log              # Nginx 에러 로그
tail -f /var/log/nginx/access.log             # Nginx 접근 로그

# 프론트엔드 헬스 체크
curl -s http://localhost:3000/
curl -s http://localhost/

# 프론트엔드 재배포 테스트
sudo /home/ubuntu/deploy-fe.sh
```

### 3.3 프론트엔드 Nginx 설정 확인

```bash
# Nginx 설정 테스트
sudo nginx -t

# 프론트엔드 Nginx 설정 확인
cat /etc/nginx/sites-available/frontend

# 심볼릭 링크 확인
ls -la /etc/nginx/sites-enabled/
```

## 4. 백엔드 테스트

### 4.1 API 테스트

```bash
# 헬스 체크 API 테스트
curl -I https://dev.tebutebu.com/api/health

# API 응답 테스트
curl -s https://dev.tebutebu.com/api/health | jq

# 인증이 필요 없는 다른 API 테스트
curl -s https://dev.tebutebu.com/api/public-endpoint | jq
```

### 4.2 백엔드 인스턴스 상태 확인

```bash
# 백엔드 인스턴스 ID 확인
aws ec2 describe-instances --filters "Name=tag:Name,Values=pumati-dev-backend" --query "Reservations[].Instances[].InstanceId" --output text

# 백엔드 인스턴스에 SSH 접속
ssh -i "pumati-full-master.pem" ubuntu@{백엔드_인스턴스_IP}

# 필수 서비스 확인
systemctl status nginx
ps aux | grep java

# 포트 리스닝 확인
sudo ss -tulpn | grep ':8080'
sudo ss -tulpn | grep ':80'

# 백엔드 환경 변수 확인
ls -la /home/ubuntu/.env
grep -i "db_" /home/ubuntu/8-pumati-be/.env
grep -i "spring" /home/ubuntu/8-pumati-be/.env

# 백엔드 로그 확인
tail -f /var/log/backend-deploy.log           # 배포 로그
tail -f /home/ubuntu/8-pumati-be/spring.log   # 스프링 애플리케이션 로그
tail -f /var/log/nginx/error.log              # Nginx 에러 로그
tail -f /var/log/nginx/access.log             # Nginx 접근 로그

# 백엔드 헬스 체크
curl -s http://localhost:8080/
curl -s http://localhost:8080/api/health
curl -s http://localhost/api/health

# 백엔드 재배포 테스트
sudo /home/ubuntu/deploy-be.sh
```

### 4.3 백엔드 Nginx 설정 확인

```bash
# Nginx 설정 테스트
sudo nginx -t

# 백엔드 Nginx 설정 확인
cat /etc/nginx/sites-available/backend

# 심볼릭 링크 확인
ls -la /etc/nginx/sites-enabled/
```

### 4.4 데이터베이스 연결 테스트

```bash
# 백엔드 인스턴스에서 MySQL 접속 테스트
mysql -h {DB_HOST} -u {DB_USER} -p -e "SHOW DATABASES;"

# MySQL 연결 테스트 (상세)
mysql -h {DB_HOST} -u {DB_USER} -p{DB_PASSWORD} -e "SELECT table_schema, table_name FROM information_schema.tables WHERE table_schema='{DB_NAME}' LIMIT 5;"

# 네트워크 연결 테스트
ping -c 3 {DB_HOST}
nc -zv {DB_HOST} 3306
```

## 5. 모니터링 확인

### 5.1 CloudWatch 로그 확인

AWS 콘솔 > CloudWatch > 로그 그룹에서 다음 로그 그룹 확인:

**프론트엔드 로그 그룹:**
- `pumati-dev-frontend-deploy`
- `pumati-dev-frontend-app`
- `pumati-dev-frontend-nginx-access`
- `pumati-dev-frontend-nginx-error`

**백엔드 로그 그룹:**
- `pumati-dev-backend-deploy`
- `pumati-dev-backend-app`
- `pumati-dev-backend-nginx-access`
- `pumati-dev-backend-nginx-error`

### 5.2 지표 확인

AWS 콘솔 > CloudWatch > 지표에서 다음 지표 확인:

**프론트엔드 지표:**
- 프론트엔드 EC2 인스턴스 CPU 사용률
- 프론트엔드 타겟 그룹 정상 호스트 개수
- 프론트엔드 타겟 그룹 응답 시간

**백엔드 지표:**
- 백엔드 EC2 인스턴스 CPU 사용률
- 백엔드 타겟 그룹 정상 호스트 개수
- 백엔드 타겟 그룹 응답 시간

**공통 지표:**
- ALB 요청 개수
- ALB 5XX 에러율

## 6. 보안 테스트

```bash
# HTTPS 연결 확인
curl -I https://dev.tebutebu.com
curl -I https://dev.tebutebu.com/api/health

# SSL 인증서 정보 확인
openssl s_client -connect dev.tebutebu.com:443 -servername dev.tebutebu.com

# 보안 그룹 설정 확인
aws ec2 describe-security-groups --group-ids {프론트엔드_보안그룹ID}
aws ec2 describe-security-groups --group-ids {백엔드_보안그룹ID}
aws ec2 describe-security-groups --group-ids {ALB_보안그룹ID}

# 보안 취약점 스캔
# (주의: 필요한 권한이 있는지 확인 후 실행)
nmap -sV --script vuln dev.tebutebu.com
```

## 7. 롤백 계획

문제 발생 시 롤백 단계:

### 7.1 프론트엔드 롤백
1. 이전 버전의 프론트엔드 시작 템플릿으로 복원
2. 프론트엔드 Auto Scaling 그룹 인스턴스 새로 고침 실행
3. 필요 시 수동으로 이전 버전 배포: `sudo /home/ubuntu/deploy-fe.sh`

### 7.2 백엔드 롤백
1. 이전 버전의 백엔드 시작 템플릿으로 복원
2. 백엔드 Auto Scaling 그룹 인스턴스 새로 고침 실행 
3. 필요 시 수동으로 이전 버전 배포: `sudo /home/ubuntu/deploy-be.sh`

## 8. 문제 해결

### 8.1 프론트엔드 흔한 문제 및 해결책

- **빌드 실패**: `npm` 대신 `pnpm` 사용 확인, 의존성 설치 확인
- **Nginx 연결 실패**: Nginx 설정, 포트 리스닝 확인, 3000 포트가 실행 중인지 확인
- **환경 변수 문제**: `.env` 파일이 올바르게 생성되었는지 확인
- **화면 렌더링 문제**: 렌더링 오류, 콘솔 오류 확인, 브라우저 캐시 삭제

### 8.2 백엔드 흔한 문제 및 해결책

- **데이터베이스 연결 실패**: DB 호스트, 보안 그룹, 자격 증명 확인
- **스프링 부트 시작 실패**: JDK 버전, 메모리 설정, 환경 변수 확인
- **API 응답 오류**: 엔드포인트 구현, 로그 확인, 데이터베이스 쿼리 검토
- **Nginx 연결 실패**: 8080 포트 실행 중인지 확인, Nginx 설정 확인

### 8.3 로그 수집 및 문제 보고

문제 발생 시 다음 정보를 수집하세요:

- 발생 시간 (한국 시간 기준)
- 오류 메시지 및 화면 캡처
- 관련 로그 (배포 로그, 애플리케이션 로그, Nginx 로그)
- 재현 단계
- 사용자 환경 (브라우저, 기기 등)

이 정보를 바탕으로 상세한 문제 보고서를 작성하여 개발팀에 전달하세요.

## 9. 추가 리소스

- [AWS ELB 문서](https://docs.aws.amazon.com/elasticloadbalancing/)
- [Terraform AWS 프로바이더 문서](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Nginx 설정 가이드](https://nginx.org/en/docs/)
- [Spring Boot 애플리케이션 배포 가이드](https://docs.spring.io/spring-boot/docs/current/reference/html/deployment.html)
- [Next.js 배포 가이드](https://nextjs.org/docs/deployment)
