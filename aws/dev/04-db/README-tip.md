# 04-DB 모듈 설치 테스트 가이드

이 가이드는 04-DB 모듈이 성공적으로 배포된 후 SSH를 통해 접속하여 MySQL 설정을 확인하는 방법을 설명합니다.

## 1. SSH 접속하기

```bash
# EC2 인스턴스에 SSH 접속
# 키 페어 파일(.pem)의 권한을 설정합니다
chmod 400 pumati-full-master.pem

# EC2 인스턴스에 접속합니다
ssh -i "pumati-full-master.pem" ubuntu@[EC2_PUBLIC_IP]
```

## 2. 스타트업 스크립트 로그 확인

```bash
# 스타트업 스크립트 로그 확인
sudo cat /var/log/db-startup.log
```

## 3. MySQL 서비스 상태 확인

```bash
# 오류가 있는지 확인
grep -i error /var/log/db-startup.log

# MySQL 서비스 상태 확인 (Ubuntu에서는 mysql.service 사용)
sudo systemctl status mysql

# 만약 서비스가 실행 중이 아니라면 시작
sudo systemctl start mysql
```

## 4. MySQL 데이터베이스 접속 테스트

```bash
# MySQL 접속 (루트 계정)
sudo mysql -u root -p
# 비밀번호 입력 프롬프트에 DB 비밀번호 입력

# MySQL 프롬프트에서 다음 명령 실행
mysql> SHOW DATABASES;  # 데이터베이스 목록 확인 (tbdb가 있어야 함)
mysql> SELECT Host, User FROM mysql.user;  # 사용자 목록 확인 (tbuser가 있어야 함)
mysql> SHOW GRANTS FOR 'tbuser'@'%';  # tbuser 권한 확인
mysql> exit;  # MySQL 종료

# tbuser 계정으로 접속 테스트
mysql -u tbuser -p
# 비밀번호 입력

# 데이터베이스 선택 및 테이블 확인
mysql> USE tbdb;
mysql> SHOW TABLES;
mysql> exit;
```

## 5. 타임존 설정 확인

```bash
# 시스템 타임존 확인
timedatectl

# MySQL 타임존 설정 확인
sudo mysql -u root -p -e "SELECT @@global.time_zone, @@session.time_zone;"
# 비밀번호 입력 프롬프트에 DB 비밀번호 입력
# 출력 결과가 '+09:00' 또는 'Asia/Seoul'로 표시되어야 함

# 현재 MySQL 서버 시간 확인
sudo mysql -u root -p -e "SELECT NOW();"
# 결과가 한국 시간(KST)으로 표시되어야 함
```

## 6. 백업 스크립트 확인

```bash
# 백업 스크립트 확인
cat /usr/local/bin/db-backup.sh

# 스크립트 실행 권한 확인
ls -l /usr/local/bin/db-backup.sh

# Cron 작업 확인 (매일 아침 9시에 실행되도록 설정됨)
sudo crontab -l
```

## 7. 백업 스크립트 수동 실행 테스트

```bash
# 백업 스크립트 수동 실행
sudo /usr/local/bin/db-backup.sh

# 백업 로그 확인
sudo cat /var/log/db-backup.log

# S3 버킷에 백업 파일이 업로드되었는지 확인
sudo aws s3 ls s3://[S3_BUCKET_NAME]/backups/
```

## 8. S3 백업 파일 복원하기

```bash
# 복원 스크립트 확인
cat /usr/local/bin/db-restore.sh

# 스크립트 실행 권한 확인
ls -l /usr/local/bin/db-restore.sh

# S3 버킷에서 사용 가능한 백업 파일 목록 확인
sudo aws s3 ls s3://[S3_BUCKET_NAME]/backups/

# 백업 파일 복원 (특정 백업 파일 지정)
sudo /usr/local/bin/db-restore.sh -f [BACKUP_FILE_NAME]

# 예시: tbdb-2023-05-21_09-00-00.sql.gz 파일 복원
sudo /usr/local/bin/db-restore.sh -f tbdb-2023-05-21_09-00-00.sql.gz

# 복원 로그 확인
sudo cat /var/log/db-restore.log

# 복원 후 데이터베이스 확인
sudo mysql -u root -p -e "USE tbdb; SHOW TABLES;"
```

## 9. MySQL 원격 접속 테스트

```bash
# 로컬 컴퓨터에서 실행
mysql -h [EC2_PUBLIC_IP] -u tbuser -p tbdb
# 비밀번호 입력
```

## 10. 보안 그룹 설정 확인

```bash
# EC2 인스턴스에서 실행
# 방화벽 상태 확인
sudo iptables -L

# MySQL 포트 리스닝 확인
sudo netstat -tulpn | grep mysql
# 또는 다음 명령어 사용 (netstat이 없는 경우)
sudo ss -tulpn | grep mysql
```

## 11. MySQL 설정 파일 확인

```bash
# MySQL 설정 파일 확인 (Ubuntu에서의 위치)
sudo cat /etc/mysql/mysql.conf.d/mysqld.cnf

# bind-address 설정이 0.0.0.0으로 되어 있는지 확인
grep bind-address /etc/mysql/mysql.conf.d/mysqld.cnf

# 타임존 설정 파일 확인
sudo cat /etc/mysql/conf.d/timezone.cnf
# default-time-zone='+09:00' 설정이 있어야 함
```