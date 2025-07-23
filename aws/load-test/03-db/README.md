# 03-db: DocumentDB (MongoDB 호환) 부하 테스트 환경

부하 테스트를 위한 DocumentDB 클러스터를 구성합니다.

## 📋 DocumentDB 아키텍처

### 🎯 **클러스터 구성**
- **엔진**: DocumentDB 5.0 (MongoDB 호환)
- **마스터**: 1개 인스턴스 (쓰기 전용)
- **읽기 전용**: 2개 인스턴스 (읽기 부하 분산)
- **인스턴스 타입**: `db.t3.medium` (DocumentDB 최소 지원)

### 🚀 **부하 테스트 최적화**
- **TLS 비활성화**: 성능 향상을 위해 TLS 비활성화
- **백업 최소화**: 1일 백업 보관으로 비용 절약
- **모니터링 최소화**: 고급 모니터링 비활성화
- **로그 최소화**: 3일 보관으로 비용 절약

## 포함된 리소스

### 🗄️ **DocumentDB 클러스터**
- **클러스터**: MongoDB 호환 DocumentDB 클러스터
- **마스터 인스턴스**: 쓰기 작업 전용
- **읽기 전용 인스턴스**: 2개로 읽기 부하 분산
- **파라미터 그룹**: 부하 테스트 최적화 설정

### 🔒 **보안 설정**
- **보안 그룹**: VPC 내에서만 27017 포트 접근 허용
- **서브넷 그룹**: 퍼블릭 서브넷 사용 (부하 테스트용)
- **암호화**: 저장 데이터 암호화 활성화

### 📊 **모니터링**
- **CloudWatch 로그**: audit, profiler 로그 수집
- **알람**: CPU 사용률, 읽기 지연시간 모니터링
- **로그 보관**: 3일간 보관 (비용 최적화)

## 사용 방법

1. **사전 요구사항 확인**
   ```bash
   cd ../00-common && terraform output
   cd ../02-network && terraform output
   ```

2. **DB 비밀번호 설정**
   ```bash
   # secrets.auto.tfvars 파일에 비밀번호 설정
   echo 'db_password = "your-secure-password"' > secrets.auto.tfvars
   ```

3. **DocumentDB 클러스터 배포**
   ```bash
   cd aws/load-test/03-db
   terraform init
   terraform plan
   terraform apply
   ```

4. **배포 결과 확인**
   ```bash
   terraform output mongodb_connection_info
   ```

## 🔌 **연결 정보**

### **엔드포인트**
- **쓰기용**: `pumati-load-test-docdb-cluster.cluster-xxxxx.docdb.ap-northeast-2.amazonaws.com:27017`
- **읽기용**: `pumati-load-test-docdb-cluster.cluster-ro-xxxxx.docdb.ap-northeast-2.amazonaws.com:27017`

### **연결 문자열 예시**
```javascript
// Node.js MongoDB 드라이버
const MongoClient = require('mongodb').MongoClient;

// 쓰기용 연결
const writeUri = "mongodb://admin:<password>@<cluster-endpoint>:27017/pumati_load_test?ssl=false&replicaSet=rs0";

// 읽기용 연결 (읽기 전용 인스턴스)
const readUri = "mongodb://admin:<password>@<reader-endpoint>:27017/pumati_load_test?ssl=false&replicaSet=rs0&readPreference=secondary";
```

## ⚠️ 부하 테스트 주의사항

### **성능 설정**
- **TLS 비활성화**: 성능 향상을 위해 SSL/TLS 비활성화됨
- **읽기 분산**: 읽기 작업은 읽기 전용 인스턴스로 분산
- **연결 풀**: 애플리케이션에서 적절한 연결 풀 설정 필요

### **보안 고려사항**
- **VPC 내부 접근**: 퍼블릭 서브넷에 위치하지만 보안 그룹으로 접근 제어
- **비밀번호 관리**: Secrets Manager 사용 (필요시)
- **임시 환경**: 부하 테스트 완료 후 즉시 정리 권장

### **비용 최적화**
- **최소 백업**: 1일 백업 보관
- **모니터링 제한**: 기본 CloudWatch 메트릭만 사용
- **로그 제한**: 3일간만 보관

## 다음 단계

DocumentDB 구성 완료 후:
- `04-compute`: EKS 클러스터 구성
- 애플리케이션에서 MongoDB 드라이버로 연결
- 부하 테스트 실행 및 성능 모니터링

## 🧹 **정리**

부하 테스트 완료 후 리소스 정리:
```bash
terraform destroy -auto-approve
```

**주의**: DocumentDB는 삭제 보호가 비활성화되어 있어 쉽게 삭제됩니다.