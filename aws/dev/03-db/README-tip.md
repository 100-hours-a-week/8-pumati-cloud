# 📊 Test 환경 - 데이터베이스 (03-db)

Test 환경의 MySQL 데이터베이스 서버를 구성하는 Terraform 인프라입니다.

## 🏗️ 인프라 구성

- **EC2 인스턴스**: Amazon Linux 2023 기반 MySQL 8.0 서버
- **스토리지**: 50GB gp3 SSD (암호화)
- **보안**: Secrets Manager로 비밀번호 관리
- **백업**: 자동 S3 백업 시스템 (매일 09:00) + 복원 스크립트
- **네트워크**: Private 서브넷에 배치 (DB 서브넷)
- **접근**: Session Manager로 접속

## 🚀 배포 방법

```bash
# 1. 디렉터리 이동
cd aws/test/03-db

# 2. Terraform 초기화
terraform init

# 3. 계획 확인
terraform plan

# 4. 배포 실행
terraform apply
```

## ✅ **간단한 DB 테스트 방법**

### **1단계: Session Manager로 인스턴스 접속**

1. **AWS 콘솔** → **EC2** → **인스턴스** 이동
2. **`pumati-test-mysql`** 인스턴스 선택  
3. **연결** → **Session Manager** → **연결** 클릭


### **로그 확인**

```bash
# 🔍 DB 시작 로그
sudo tail -20 /var/log/db-startup.log

# 🔍 MySQL 에러 로그  
sudo tail -20 /var/log/mysqld.log

# 🔍 백업 로그
sudo tail -20 /var/log/db-backup.log

# 🔍 사용자 데이터 로그
sudo tail -20 /var/log/user-data.log
```

### **2단계: 환경 변수 및 MySQL 상태 확인**

```bash
# 환경변수에서 DB 비밀번호 가져오기
DB_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id pumati-test-db-password \
  --region ap-northeast-2 \
  --query SecretString --output text)

# MySQL 서비스 상태 확인
sudo systemctl status mysqld

# MySQL 프로세스 확인  
ps aux | grep mysql
```

### **3단계: 데이터베이스 연결 테스트**

```bash
# ✅ root 계정으로 연결 테스트
mysql -u root -p$DB_PASSWORD -e "SELECT VERSION();"

# ✅ tbuser 계정으로 연결 테스트  
mysql -u tbuser -p$DB_PASSWORD tbdb -e "SELECT DATABASE();"

# ✅ 데이터베이스 목록 확인
mysql -u root -p$DB_PASSWORD -e "SHOW DATABASES;"
```

### **4단계: 복원된 데이터 확인**

```bash
# ✅ 테이블 목록 확인
mysql -u tbuser -p$DB_PASSWORD tbdb -e "SHOW TABLES;"

# ✅ 각 테이블의 데이터 개수 확인
mysql -u tbuser -p$DB_PASSWORD tbdb -e "
SELECT 
  table_name,
  table_rows 
FROM 
  information_schema.tables 
WHERE 
  table_schema = 'tbdb'
ORDER BY table_name;"

# ✅ 특정 테이블 데이터 샘플 확인 (예: member 테이블)
mysql -u tbuser -p$DB_PASSWORD tbdb -e "SELECT * FROM member LIMIT 5;"
```

### **5단계: 타임존 및 백업 시스템 확인**

```bash  
# ✅ MySQL 타임존 확인 (한국시간이어야 함)
mysql -u root -p$DB_PASSWORD -e "SELECT @@global.time_zone, @@session.time_zone, NOW();"

# ✅ 백업 스크립트 확인
ls -la /usr/local/bin/db-backup.sh
ls -la /usr/local/bin/db-restore.sh

# ✅ cron 백업 작업 확인
crontab -l

# ✅ 복원 스크립트 도움말 확인
/usr/local/bin/db-restore.sh --help
```

## 🔧 **유용한 명령어들**

### **백업 관련**

```bash
# 수동 백업 실행
sudo /usr/local/bin/db-backup.sh

# 백업 파일 목록 확인
/usr/local/bin/db-restore.sh --list

# S3 백업 폴더 확인  
aws s3 ls s3://pumati-s3-jacky/backups/ --recursive

# 특정 백업으로 복원 (주의!)
/usr/local/bin/db-restore.sh --specific tbdb-2025-06-01_18-00-01.sql.gz
```

### **로그 확인**

```bash
# 🔍 DB 시작 로그
sudo tail -20 /var/log/db-startup.log

# 🔍 MySQL 에러 로그  
sudo tail -20 /var/log/mysqld.log

# 🔍 백업 로그
sudo tail -20 /var/log/db-backup.log

# 🔍 사용자 데이터 로그
sudo tail -20 /var/log/user-data.log
```

## 🚨 **예상되는 테스트 결과**

### **✅ 정상 작동 시**

```bash
# MySQL 버전 확인 결과 예시
mysql> SELECT VERSION();
+-----------+
| VERSION() |
+-----------+
| 8.0.42    |
+-----------+

# 테이블 목록 결과 예시  
mysql> SHOW TABLES;
+--------------------------+
| Tables_in_tbdb           |
+--------------------------+
| attendance_daily         |
| attendance_weekly        |
| comment                  |
| member                   |
| member_team_badge        |
| oauth                    |
| project                  |
| project_image            |
| project_ranking_snapshot |
| project_tag              |
| refresh_token            |
| tag                      |
| team                     |
+--------------------------+
13 rows in set (0.00 sec)

# 타임존 확인 결과 예시
mysql> SELECT @@global.time_zone, @@session.time_zone, NOW();
+------------------+-------------------+---------------------+
| @@global.time_zone | @@session.time_zone | NOW()               |
+------------------+-------------------+---------------------+
| +09:00           | +09:00            | 2025-06-02 22:30:15 |
+------------------+-------------------+---------------------+
```

## 🛠️ **트러블슈팅**

### **Connection 실패 시**

```bash
# MySQL 서비스 재시작
sudo systemctl restart mysqld

# 네트워크 상태 확인
sudo netstat -tlnp | grep 3306

# Secrets Manager 접근 확인  
aws secretsmanager get-secret-value --secret-id pumati-test-db-password --region ap-northeast-2
```

### **데이터가 없을 시**

```bash  
# 백업 복원 재실행
/usr/local/bin/db-restore.sh --fallback

# S3 fallback 파일 확인
aws s3 ls s3://pumati-test-db-backup/tbdb-2025-06-01_18-00-01.sql.gz
```

---

💡 **참고**: 모든 명령어는 Session Manager 연결 후 실행하며, 비밀번호는 Secrets Manager에서 자동으로 가져옵니다!
