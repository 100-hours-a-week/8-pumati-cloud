# Load Test MongoDB 모듈

## 📋 **개요**
로드테스트 환경용 MongoDB 7.0 단일 인스턴스를 구성하는 Terraform 모듈입니다.

## 🚀 **배포 방법**
```bash
cd load-test-dev/02-mongoDB
terraform init
terraform plan
terraform apply
```

## 🔍 **설치 검증 방법**

### 1. **기본 검증 스크립트 실행**
```bash
# SSH 접속
ssh -i ~/.ssh/8-ktb-chat-keypair.pem ubuntu@<PUBLIC_IP>

# 자동 검증 스크립트 실행
verify-mongodb-setup.sh
```

**예상 출력:**
```
=== MongoDB 검증 ===
서비스: active
✅ MongoDB 연결 성공
포트: 1개 리스닝
연결: mongodb://10.10.1.96:27017/loadtest
```

### 2. **수동 검증 방법**

#### MongoDB 서비스 상태 확인
```bash
# 서비스 상태
sudo systemctl status mongod

# 서비스 활성화 여부
systemctl is-active mongod
```

#### MongoDB 연결 테스트
```bash
# 로컬 연결 테스트
mongosh

# 데이터베이스 확인
mongosh --eval "use loadtest; db.test.find()"
```

#### 포트 리스닝 확인
```bash
# MongoDB 포트 확인
sudo netstat -tlnp | grep 27017

# 또는
ss -tlnp | grep 27017
```

#### 로그 확인
```bash
# 설치 로그
sudo tail -50 /var/log/mongodb-install.log

# MongoDB 로그
sudo tail -20 /var/log/mongodb/mongod.log

# 서비스 로그
sudo journalctl -u mongod -f
```

### 3. **외부에서 연결 테스트**
```bash
# 외부에서 MongoDB 연결 (mongosh 설치 필요)
mongosh mongodb://<PUBLIC_IP>:27017/loadtest

# 또는 ping 테스트
telnet <PUBLIC_IP> 27017
```

### 4. **모니터링 스크립트**
```bash
# 간단한 상태 확인
mongodb-stats.sh

# CloudWatch Agent 상태
sudo systemctl status amazon-cloudwatch-agent
```

## 🔧 **연결 정보**

### 내부 네트워크 연결
```
mongodb://<PRIVATE_IP>:27017/loadtest
```

### 외부 연결 (개발/테스트용)
```
mongodb://<PUBLIC_IP>:27017/loadtest
```

## 🐛 **문제 해결**

### MongoDB 서비스 시작 실패
```bash
# 상세 상태 확인
sudo systemctl status mongod

# 로그 확인
sudo journalctl -u mongod --no-pager

# 설정 파일 확인
sudo cat /etc/mongod.conf

# 권한 확인
sudo ls -la /var/lib/mongodb /var/run/mongodb
```

### 연결 실패
```bash
# 방화벽 상태 확인
sudo ufw status

# 포트 확인
sudo netstat -tlnp | grep 27017

# MongoDB 프로세스 확인
ps aux | grep mongod
```

### 스크립트 실행 로그 확인
```bash
# 전체 설치 로그
sudo cat /var/log/mongodb-install.log

# 오류만 확인
sudo grep -i error /var/log/mongodb-install.log
```

## 📊 **출력 변수**
- `mongodb_private_ip`: 프라이빗 IP
- `mongodb_public_ip`: 퍼블릭 IP (Elastic IP)
- `mongodb_connection_string`: 내부 연결 문자열
- `mongodb_external_connection_string`: 외부 연결 문자열

## ⚠️ **주의사항**
- 현재 SSH 외부 접근이 임시로 허용되어 있습니다 (로드테스트용)
- MongoDB 인증이 비활성화되어 있습니다
- t3.small 인스턴스는 로드테스트용 최소 사양입니다
