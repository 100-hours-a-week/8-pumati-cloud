#!/bin/bash

# 로그 파일 설정
LOGFILE="/var/log/db-startup.log"

# 로그 기록 함수
log_message() {
  local message="$1"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] $message" | tee -a $LOGFILE
}

log_message "시작: ${project_name}-${environment} 데이터베이스 서버 설정 스크립트"

# 환경 변수 설정
DB_NAME="${db_name}"
DB_USERNAME="${db_username}"
DB_PASSWORD="${db_password}"
S3_BUCKET="${s3_bucket_name}"
BACKUP_URL="https://pumati-dev-db-backup.s3.ap-northeast-2.amazonaws.com/backup-20250521.sql.gz"
BACKUP_FILE="backup-20250521.sql.gz"
BACKUP_DIR="/tmp/db-restore"

# 시스템 타임존을 한국 시간(KST)으로 설정
log_message "시스템 타임존을 KST(한국 표준시)로 설정 중..."
timedatectl set-timezone Asia/Seoul >> $LOGFILE 2>&1
log_message "시스템 타임존 설정 완료: $(date)"

# Ubuntu 용 패키지 관리자 사용
log_message "시스템 패키지 업데이트 중..."
apt-get update && apt-get upgrade -y >> $LOGFILE 2>&1
log_message "시스템 업데이트 완료"

# 필요한 패키지 설치 (Ubuntu에서는 mysql-server)
log_message "필요한 패키지 설치 중..."
apt-get install -y mysql-server jq curl awscli >> $LOGFILE 2>&1
log_message "패키지 설치 완료"

# MySQL 서비스 이름을 Ubuntu에 맞게 변경
log_message "MySQL 서비스 시작 및 자동 시작 설정 중..."
systemctl start mysql >> $LOGFILE 2>&1
systemctl enable mysql >> $LOGFILE 2>&1
log_message "MySQL 서비스 설정 완료"

# MySQL 초기 설정 및 비밀번호 설정 (Ubuntu에서는 다르게 처리)
log_message "MySQL 보안 설정 중..."
# Ubuntu에서 MySQL 루트 비밀번호 설정
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$DB_PASSWORD';" >> $LOGFILE 2>&1
mysql -u root -p$DB_PASSWORD -e "DELETE FROM mysql.user WHERE User='';" >> $LOGFILE 2>&1
mysql -u root -p$DB_PASSWORD -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" >> $LOGFILE 2>&1
mysql -u root -p$DB_PASSWORD -e "DROP DATABASE IF EXISTS test;" >> $LOGFILE 2>&1
mysql -u root -p$DB_PASSWORD -e "FLUSH PRIVILEGES;" >> $LOGFILE 2>&1
log_message "MySQL 보안 설정 완료"

# MySQL 타임존을 KST로 설정
log_message "MySQL 타임존을 KST(한국 표준시)로 설정 중..."
mysql -u root -p$DB_PASSWORD -e "SET GLOBAL time_zone='Asia/Seoul';" >> $LOGFILE 2>&1
mysql -u root -p$DB_PASSWORD -e "SET time_zone='Asia/Seoul';" >> $LOGFILE 2>&1

# MySQL 설정 파일에 타임존 영구 설정 추가
mysql_tz_cnf="/etc/mysql/conf.d/timezone.cnf"
echo "[mysqld]" | sudo tee $mysql_tz_cnf > /dev/null
echo "default-time-zone='+09:00'" | sudo tee -a $mysql_tz_cnf > /dev/null
log_message "MySQL 타임존 설정 완료"

# 데이터베이스 및 사용자 생성
log_message "데이터베이스 및 사용자 생성 중..."
mysql -u root -p$DB_PASSWORD <<MYSQL_SCRIPT >> $LOGFILE 2>&1
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USERNAME'@'%' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USERNAME'@'%';
FLUSH PRIVILEGES;
MYSQL_SCRIPT
log_message "데이터베이스 및 사용자 생성 완료"

# MySQL 원격 접속 허용 설정 (Ubuntu의 MySQL 설정 파일 경로가 다름)
log_message "MySQL 원격 접속 설정 중..."
# Ubuntu의 MySQL 설정 파일
mysql_cnf="/etc/mysql/mysql.conf.d/mysqld.cnf"
if [ -f "$mysql_cnf" ]; then
  if grep -q "bind-address" $mysql_cnf; then
    sudo sed -i 's/bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/' $mysql_cnf
  else
    echo "bind-address = 0.0.0.0" | sudo tee -a $mysql_cnf
  fi
else
  # 설정 파일이 없는 경우 새로 생성
  echo "[mysqld]" | sudo tee /etc/mysql/conf.d/mysql-custom.cnf > /dev/null
  echo "bind-address = 0.0.0.0" | sudo tee -a /etc/mysql/conf.d/mysql-custom.cnf > /dev/null
fi
log_message "MySQL 원격 접속 설정 완료"

# 나머지 코드에서도 서비스 이름을 mysql로 변경
log_message "MySQL 서비스 재시작 중..."
systemctl restart mysql >> $LOGFILE 2>&1
log_message "MySQL 서비스 재시작 완료"

# MySQL 타임존 설정 확인
log_message "MySQL 타임존 설정 확인..."
mysql -u root -p$DB_PASSWORD -e "SELECT @@global.time_zone, @@session.time_zone;" >> $LOGFILE 2>&1

# MySQL 상태 확인
if systemctl is-active --quiet mysql; then
  log_message "MySQL 서비스가 정상적으로 실행 중입니다."
else
  log_message "MySQL 서비스 시작 실패!"
fi

# S3 스토리지에서 백업 파일 가져와서 DB 복원하기
log_message "S3 스토리지에서 초기 데이터베이스 백업 파일 가져오는 중..."

# 작업 디렉토리 생성
mkdir -p $BACKUP_DIR
cd $BACKUP_DIR

# S3에서 백업 파일 다운로드
log_message "백업 파일 다운로드 중: $BACKUP_URL"
aws s3 cp s3://$S3_BUCKET/backup-20250521.sql.gz . >> $LOGFILE 2>&1

# 다운로드 실패 시 직접 URL로 시도
if [ $? -ne 0 ]; then
  log_message "S3 다운로드 실패, URL로 직접 다운로드 시도 중..."
  curl -o $BACKUP_FILE $BACKUP_URL >> $LOGFILE 2>&1
  
  if [ $? -ne 0 ]; then
    log_message "오류: 백업 파일 다운로드 실패!"
  else
    log_message "URL에서 백업 파일 다운로드 성공"
  fi
else
  log_message "S3에서 백업 파일 다운로드 성공"
fi

if [ -f "$BACKUP_FILE" ]; then
  log_message "백업 파일 다운로드 완료: $BACKUP_FILE"
  
  # 압축 해제
  log_message "백업 파일 압축 해제 중..."
  gunzip -f $BACKUP_FILE
  if [ $? -ne 0 ]; then
    log_message "오류: 백업 파일 압축 해제 실패!"
  else
    # .gz 확장자 제거한 파일명 얻기
    SQL_FILE=$(echo $BACKUP_FILE | sed 's/\.gz$//')
    log_message "압축 해제 완료: $SQL_FILE"
    
    # 데이터베이스 복원
    log_message "데이터베이스 복원 중..."
    mysql -u root -p$DB_PASSWORD $DB_NAME < $SQL_FILE 2>> $LOGFILE
    
    if [ $? -ne 0 ]; then
      log_message "오류: 데이터베이스 복원 실패!"
    else
      log_message "데이터베이스 초기 데이터 복원 완료!"
    fi
  fi
  
  # 임시 파일 정리
  log_message "임시 파일 정리 중..."
  cd /
  rm -rf $BACKUP_DIR
  log_message "임시 파일 정리 완료"
else
  log_message "백업 파일이 존재하지 않습니다. 초기 데이터 복원을 건너뜁니다."
fi

# DB 백업 스크립트 생성
log_message "DB 백업 스크립트 생성 중..."

cat > /usr/local/bin/db-backup.sh << EOF
#!/bin/bash

# DB 연결 정보
DB_NAME="${db_name}"
DB_USER="root"
DB_PASSWORD="${db_password}"

# S3 버킷 정보
S3_BUCKET="${s3_bucket_name}"

# 백업 파일 설정
TIMESTAMP=\$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_DIR="/tmp/db-backups"
BACKUP_FILE="\$BACKUP_DIR/\$DB_NAME-\$TIMESTAMP.sql"
LOG_FILE="/var/log/db-backup.log"

# 로그 함수
log_backup() {
  echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$1" >> \$LOG_FILE
}

# 백업 디렉터리 생성
mkdir -p \$BACKUP_DIR

# 백업 시작 로그
log_backup "MySQL 백업 시작: \$DB_NAME"

# mysqldump 실행
mysqldump -u \$DB_USER -p\$DB_PASSWORD \$DB_NAME > \$BACKUP_FILE

# 백업 성공 여부 확인
if [ \$? -eq 0 ]; then
  log_backup "백업 파일 생성 성공: \$BACKUP_FILE"
  
  # 파일 압축
  GZIP_FILE="\$BACKUP_FILE.gz"
  gzip -f \$BACKUP_FILE
  
  # S3에 업로드
  aws s3 cp \$GZIP_FILE s3://\$S3_BUCKET/backups/\$(basename \$GZIP_FILE)
  
  # 업로드 결과 확인
  if [ \$? -eq 0 ]; then
    log_backup "S3 업로드 성공: s3://\$S3_BUCKET/backups/\$(basename \$GZIP_FILE)"
  else
    log_backup "S3 업로드 실패!"
  fi
  
  # 임시 파일 정리
  rm -f \$GZIP_FILE
  log_backup "임시 파일 정리 완료"
else
  log_backup "백업 실패!"
fi

log_backup "백업 작업 완료"

# 오래된 로그 정리 (30일 이상)
find \$LOG_FILE -type f -mtime +30 -exec truncate -s 0 {} \;
EOF

# 스크립트 실행 권한 부여
chmod +x /usr/local/bin/db-backup.sh
log_message "DB 백업 스크립트 생성 완료"

# DB 복원 스크립트 생성
log_message "DB 복원 스크립트 생성 중..."

cat > /usr/local/bin/db-restore.sh << EOF
#!/bin/bash

# 로그 파일 설정
LOGFILE="/var/log/db-restore.log"

# 로그 기록 함수
log_message() {
  local message="\$1"
  local timestamp=\$(date '+%Y-%m-%d %H:%M:%S')
  echo "[\$timestamp] \$message" | tee -a \$LOGFILE
}

# 기본 변수 설정
DB_NAME="${db_name}"
DB_USER="root"
DB_PASSWORD="${db_password}"
BACKUP_DIR="/tmp/db-restore"
TIMESTAMP=\$(date +%Y-%m-%d_%H-%M-%S)

# 사용법 함수
usage() {
  echo "사용법: \$0 [옵션]"
  echo "옵션:"
  echo "  -b, --bucket BUCKET_NAME   S3 버킷 이름 (생략 시 기본값: ${s3_bucket_name})"
  echo "  -f, --file FILE_NAME       복원할 백업 파일 이름 (필수)"
  echo "  -h, --help                 도움말 표시"
  exit 1
}

# 명령행 인자 파싱
while [[ \$# -gt 0 ]]; do
  case \$1 in
    -b|--bucket)
      S3_BUCKET="\$2"
      shift 2
      ;;
    -f|--file)
      BACKUP_FILE="\$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "알 수 없는 옵션: \$1"
      usage
      ;;
  esac
done

# 기본값 설정
S3_BUCKET="\$S3_BUCKET"
if [ -z "\$S3_BUCKET" ]; then
  S3_BUCKET="${s3_bucket_name}"
fi

# 필수 인자 확인
if [ -z "\$BACKUP_FILE" ]; then
  echo "오류: 복원할 백업 파일 이름을 지정해야 합니다."
  usage
fi

log_message "시작: MySQL 데이터베이스 백업 복원 스크립트"

# 작업 디렉토리 생성
mkdir -p \$BACKUP_DIR
cd \$BACKUP_DIR

# S3에서 백업 파일 다운로드
log_message "S3에서 백업 파일 다운로드 중: s3://\$S3_BUCKET/backups/\$BACKUP_FILE"
aws s3 cp s3://\$S3_BUCKET/backups/\$BACKUP_FILE . >> \$LOGFILE 2>&1

if [ \$? -ne 0 ]; then
  log_message "오류: S3에서 백업 파일 다운로드 실패!"
  exit 1
fi

log_message "백업 파일 다운로드 완료: \$BACKUP_FILE"

# 압축 해제 (파일이 .gz로 끝나는 경우)
if [[ \$BACKUP_FILE == *.gz ]]; then
  log_message "백업 파일 압축 해제 중..."
  gunzip -f \$BACKUP_FILE
  if [ \$? -ne 0 ]; then
    log_message "오류: 백업 파일 압축 해제 실패!"
    exit 1
  fi
  # .gz 확장자 제거
  SQL_FILE=\$(echo \$BACKUP_FILE | sed 's/\.gz$//')
else
  SQL_FILE=\$BACKUP_FILE
fi

log_message "압축 해제 완료: \$SQL_FILE"

# 기존 데이터베이스 백업 (안전 조치)
log_message "기존 데이터베이스 백업 중..."
mysqldump -u \$DB_USER -p\$DB_PASSWORD \$DB_NAME > \$DB_NAME"_before_restore_"\$TIMESTAMP.sql 2>> \$LOGFILE
if [ \$? -ne 0 ]; then
  log_message "경고: 기존 데이터베이스 백업 실패! 복원 작업을 계속하시겠습니까? (y/n)"
  read -p "계속하시겠습니까? (y/n): " confirm
  if [[ \$confirm != [yY] ]]; then
    log_message "사용자에 의해 복원 작업 취소됨"
    exit 1
  fi
fi

# 데이터베이스 복원
log_message "데이터베이스 복원 중..."
mysql -u \$DB_USER -p\$DB_PASSWORD \$DB_NAME < \$SQL_FILE 2>> \$LOGFILE

if [ \$? -ne 0 ]; then
  log_message "오류: 데이터베이스 복원 실패!"
  log_message "백업 파일을 확인하고 다시 시도하세요."
  exit 1
fi

log_message "데이터베이스 복원 완료!"

# 임시 파일 정리
log_message "임시 파일 정리 중..."
cd /
rm -rf \$BACKUP_DIR
log_message "임시 파일 정리 완료"

log_message "완료: MySQL 데이터베이스 백업 복원 스크립트"
echo "데이터베이스 복원이 성공적으로 완료되었습니다!"
EOF

# 스크립트 실행 권한 부여
chmod +x /usr/local/bin/db-restore.sh
log_message "DB 복원 스크립트 생성 완료"

# cron 작업 설정 (매일 아침 9시)
log_message "백업 cron 작업 설정 중..."
echo "0 9 * * * /usr/local/bin/db-backup.sh" | crontab -
log_message "백업 cron 작업 설정 완료"

log_message "완료: ${project_name}-${environment} 데이터베이스 서버 설정 스크립트"