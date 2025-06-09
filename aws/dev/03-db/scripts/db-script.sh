#!/bin/bash

# 로그 파일 설정
LOGFILE="/var/log/db-startup.log"

# 로그 기록 함수
log_message() {
  local message="$1"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] $message" | tee -a $LOGFILE
}

log_message "시작: DB 서버 설정 스크립트"

# 환경 변수 확인 (startup-script.sh에서 export된 변수들 사용)
if [ -z "$PROJECT_NAME" ] || [ -z "$DB_NAME" ] || [ -z "$DB_USERNAME" ]; then
    log_message "오류: 필수 환경변수가 설정되지 않았습니다!"
    log_message "PROJECT_NAME: $PROJECT_NAME"
    log_message "DB_NAME: $DB_NAME"
    log_message "DB_USERNAME: $DB_USERNAME"
    exit 1
fi

log_message "환경변수 확인 완료:"
log_message "  PROJECT_NAME: $PROJECT_NAME"
log_message "  ENVIRONMENT: $ENVIRONMENT"
log_message "  DB_NAME: $DB_NAME"
log_message "  DB_USERNAME: $DB_USERNAME"
log_message "  S3_BUCKET_NAME: $S3_BUCKET_NAME"
log_message "  AWS_REGION: $AWS_REGION"

# 환경 변수를 로컬 변수로 설정 (환경변수 사용)
DB_NAME="$DB_NAME"
DB_USERNAME="$DB_USERNAME"
DB_PASSWORD_SECRET_NAME="$DB_PASSWORD_SECRET_NAME"
AWS_REGION="$AWS_REGION"
S3_BUCKET="$S3_BUCKET_NAME"
BACKUP_DIR="/tmp/db-restore"

# 시스템 타임존을 한국 시간(KST)으로 설정
log_message "시스템 타임존을 KST(한국 표준시)로 설정 중..."
timedatectl set-timezone Asia/Seoul >> $LOGFILE 2>&1
log_message "시스템 타임존 설정 완료: $(date)"

# Amazon Linux 패키지 업데이트
log_message "시스템 패키지 업데이트 중..."
dnf update -y >> $LOGFILE 2>&1
log_message "시스템 업데이트 완료"

# 기본 패키지 설치
log_message "기본 패키지 설치 중..."
dnf install -y jq curl >> $LOGFILE 2>&1
log_message "기본 패키지 설치 완료"

# AWS CLI 버전 확인 (Amazon Linux에 기본 설치됨)
log_message "AWS CLI 버전 확인: $(aws --version)"
aws configure set default.region $AWS_REGION

# Secrets Manager에서 비밀번호 가져오기 (재시도 로직 포함)
log_message "Secrets Manager에서 데이터베이스 비밀번호 가져오는 중..."
RETRY_COUNT=0
MAX_RETRIES=5

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id $DB_PASSWORD_SECRET_NAME --region $AWS_REGION --query SecretString --output text 2>>$LOGFILE)
    
    if [ $? -eq 0 ] && [ -n "$DB_PASSWORD" ]; then
        log_message "데이터베이스 비밀번호를 성공적으로 가져왔습니다."
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        log_message "비밀번호 가져오기 실패. 재시도 $RETRY_COUNT/$MAX_RETRIES"
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            sleep 10
        fi
    fi
done

if [ -z "$DB_PASSWORD" ]; then
    log_message "오류: Secrets Manager에서 비밀번호를 가져올 수 없습니다!"
    exit 1
fi

# MySQL 8.0 리포지토리 추가 및 설치
log_message "MySQL 8.0 리포지토리 추가 중..."
dnf install -y https://dev.mysql.com/get/mysql80-community-release-el9-1.noarch.rpm >> $LOGFILE 2>&1

# MySQL GPG 키 가져오기
log_message "MySQL GPG 키 가져오기..."
rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2023 >> $LOGFILE 2>&1

# MySQL 서버 설치
log_message "MySQL 서버 설치 중..."
dnf install -y mysql-community-server >> $LOGFILE 2>&1
log_message "MySQL 서버 설치 완료"

# MySQL 서비스 시작 및 활성화
log_message "MySQL 서비스 시작 및 자동 시작 설정 중..."
systemctl start mysqld >> $LOGFILE 2>&1
systemctl enable mysqld >> $LOGFILE 2>&1
log_message "MySQL 서비스 설정 완료"

# MySQL 임시 루트 비밀번호 확인
log_message "MySQL 임시 루트 비밀번호 확인 중..."
TEMP_PASSWORD=$(grep 'temporary password' /var/log/mysqld.log | awk '{print $NF}')
log_message "임시 비밀번호를 찾았습니다."

# MySQL 보안 설정 (mysql_secure_installation 자동화)
log_message "MySQL 보안 설정 중..."

# 루트 비밀번호 변경
mysql --connect-expired-password -u root -p$TEMP_PASSWORD <<EOF >> $LOGFILE 2>&1
ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
FLUSH PRIVILEGES;
EOF

# 추가 보안 설정
mysql -u root -p$DB_PASSWORD <<EOF >> $LOGFILE 2>&1
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

log_message "MySQL 보안 설정 완료"

# MySQL 타임존을 KST로 설정
log_message "MySQL 타임존을 KST(한국 표준시)로 설정 중..."
mysql -u root -p$DB_PASSWORD <<EOF >> $LOGFILE 2>&1
SET GLOBAL time_zone='Asia/Seoul';
SET time_zone='Asia/Seoul';
EOF

# MySQL 설정 파일에 타임존 영구 설정 추가 (Amazon Linux용)
log_message "MySQL 타임존 영구 설정 추가 중..."
cat >> /etc/my.cnf << EOF

[mysqld]
default-time-zone='+09:00'
bind-address=0.0.0.0
EOF

log_message "MySQL 타임존 설정 완료"

# 데이터베이스 및 사용자 생성
log_message "데이터베이스 및 사용자 생성 중..."
mysql -u root -p$DB_PASSWORD <<EOF >> $LOGFILE 2>&1
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USERNAME'@'%' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USERNAME'@'%';
FLUSH PRIVILEGES;
EOF
log_message "데이터베이스 및 사용자 생성 완료"

# MySQL 서비스 재시작
log_message "MySQL 서비스 재시작 중..."
systemctl restart mysqld >> $LOGFILE 2>&1
log_message "MySQL 서비스 재시작 완료"

# MySQL 타임존 설정 확인
log_message "MySQL 타임존 설정 확인..."
mysql -u root -p$DB_PASSWORD -e "SELECT @@global.time_zone, @@session.time_zone;" >> $LOGFILE 2>&1

# MySQL 상태 확인
if systemctl is-active --quiet mysqld; then
  log_message "MySQL 서비스가 정상적으로 실행 중입니다."
else
  log_message "MySQL 서비스 시작 실패!"
fi

# S3에서 최신 백업 파일 검색 및 복원
log_message "S3에서 최신 백업 파일 검색 중..."

# S3에서 최신 백업 파일 찾기
LATEST_BACKUP=$(aws s3 ls s3://$S3_BUCKET/backups/ --recursive | grep '\.sql\.gz$' | sort | tail -n 1 | awk '{print $4}')

# fallback 백업 파일 S3 URI 설정 (URL 대신 S3 URI 사용)
FALLBACK_BACKUP_S3="s3://pumati-dev-db-backup/tbdb_20250609_011839.sql.gz"
FALLBACK_BACKUP_FILE="tbdb_20250609_011839.sql.gz"

# 작업 디렉터리 생성
mkdir -p $BACKUP_DIR
cd $BACKUP_DIR

if [ -z "$LATEST_BACKUP" ]; then
    log_message "경고: S3에서 최신 백업 파일을 찾을 수 없습니다. fallback 백업 파일을 사용합니다."
    
    # fallback 백업 파일 다운로드 (AWS CLI 사용으로 변경!)
    log_message "fallback 백업 파일 다운로드 중: $FALLBACK_BACKUP_S3"
    aws s3 cp $FALLBACK_BACKUP_S3 $FALLBACK_BACKUP_FILE >> $LOGFILE 2>&1
    
    if [ -f "$FALLBACK_BACKUP_FILE" ] && [ -s "$FALLBACK_BACKUP_FILE" ]; then
        BACKUP_SIZE=$(ls -lh $FALLBACK_BACKUP_FILE | awk '{print $5}')
        log_message "fallback 백업 파일 다운로드 완료: $FALLBACK_BACKUP_FILE ($BACKUP_SIZE)"
        BACKUP_FILE=$FALLBACK_BACKUP_FILE
    else
        log_message "오류: fallback 백업 파일 다운로드 실패. 데이터베이스 초기화를 건너뜁니다."
        BACKUP_FILE=""
    fi
else
    # backups/ 경로 제거하고 파일명만 추출
    BACKUP_FILE=$(basename "$LATEST_BACKUP")
    log_message "최신 백업 파일 발견: $BACKUP_FILE"

    # S3에서 최신 백업 파일 다운로드
    log_message "최신 백업 파일 다운로드 중: s3://$S3_BUCKET/$LATEST_BACKUP"
    aws s3 cp s3://$S3_BUCKET/$LATEST_BACKUP . >> $LOGFILE 2>&1

    if [ ! -f "$BACKUP_FILE" ] || [ ! -s "$BACKUP_FILE" ]; then
        log_message "경고: 최신 백업 파일 다운로드 실패. fallback 백업 파일을 시도합니다."
        
        # fallback 백업 파일 다운로드 (AWS CLI 사용)
        log_message "fallback 백업 파일 다운로드 중: $FALLBACK_BACKUP_S3"
        aws s3 cp $FALLBACK_BACKUP_S3 $FALLBACK_BACKUP_FILE >> $LOGFILE 2>&1
        
        if [ -f "$FALLBACK_BACKUP_FILE" ] && [ -s "$FALLBACK_BACKUP_FILE" ]; then
            BACKUP_SIZE=$(ls -lh $FALLBACK_BACKUP_FILE | awk '{print $5}')
            log_message "fallback 백업 파일 다운로드 완료: $FALLBACK_BACKUP_FILE ($BACKUP_SIZE)"
            BACKUP_FILE=$FALLBACK_BACKUP_FILE
        else
            log_message "오류: fallback 백업 파일 다운로드도 실패. 데이터베이스 초기화를 건너뜁니다."
            BACKUP_FILE=""
        fi
    else
        BACKUP_SIZE=$(ls -lh $BACKUP_FILE | awk '{print $5}')
        log_message "최신 백업 파일 다운로드 완료: $BACKUP_FILE ($BACKUP_SIZE)"
    fi
fi

# 백업 파일이 존재하는 경우에만 복원 진행
if [ -n "$BACKUP_FILE" ] && [ -f "$BACKUP_FILE" ] && [ -s "$BACKUP_FILE" ]; then
    log_message "백업 파일 복원 시작: $BACKUP_FILE"
    
    # 압축 해제
    log_message "백업 파일 압축 해제 중..."
    gunzip -f $BACKUP_FILE >> $LOGFILE 2>&1
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
            
            # 복원된 테이블 수 확인
            TABLE_COUNT=$(mysql -u root -p$DB_PASSWORD $DB_NAME -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$DB_NAME';" | tail -n 1)
            log_message "복원된 테이블 수: $TABLE_COUNT"
        fi
    fi
    
    # 임시 파일 정리
    log_message "임시 파일 정리 중..."
    cd /
    rm -rf $BACKUP_DIR
    log_message "임시 파일 정리 완료"
else
    log_message "백업 파일이 없어 데이터베이스 초기화를 건너뜁니다."
fi

# DB 백업 스크립트 생성
log_message "DB 백업 스크립트 생성 중..."

# 1. 현재 백업 스크립트 백업
sudo cp /usr/local/bin/db-backup.sh /usr/local/bin/db-backup.sh.backup

# 2. 새로운 백업 스크립트 생성
sudo tee /usr/local/bin/db-backup.sh > /dev/null << 'EOF'
#!/bin/bash

# 환경 변수 설정
DB_NAME="tbdb"
DB_USER="root"
AWS_REGION="ap-northeast-2"
DB_PASSWORD_SECRET_NAME="pumati-dev-db-password"
S3_BUCKET="pumati-s3-jacky"

# AWS CLI 기본 리전 설정
aws configure set default.region $AWS_REGION

# Secrets Manager에서 비밀번호 가져오기
DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id $DB_PASSWORD_SECRET_NAME --region $AWS_REGION --query SecretString --output text)

# 백업 파일 설정
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_DIR="/tmp/db-backups"
BACKUP_FILE="$BACKUP_DIR/$DB_NAME-$TIMESTAMP.sql"
LOG_FILE="/var/log/db-backup.log"

# 로그 함수
log_backup() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $LOG_FILE
}

# 백업 디렉터리 생성
mkdir -p $BACKUP_DIR

# 백업 시작 로그
log_backup "MySQL 백업 시작: $DB_NAME"

# mysqldump 실행
mysqldump -u $DB_USER -p$DB_PASSWORD $DB_NAME > $BACKUP_FILE

# 백업 성공 여부 확인
if [ $? -eq 0 ]; then
  log_backup "백업 파일 생성 성공: $BACKUP_FILE"
  
  # 파일 압축
  GZIP_FILE="$BACKUP_FILE.gz"
  gzip -f $BACKUP_FILE
  
  # S3에 업로드
  aws s3 cp $GZIP_FILE s3://$S3_BUCKET/backups/$(basename $GZIP_FILE) --region $AWS_REGION
  
  # 업로드 결과 확인
  if [ $? -eq 0 ]; then
    log_backup "S3 업로드 성공: s3://$S3_BUCKET/backups/$(basename $GZIP_FILE)"
    echo "✅ 백업 완료: $(basename $GZIP_FILE)"
  else
    log_backup "S3 업로드 실패!"
    echo "❌ S3 업로드 실패!"
  fi
  
  # 임시 파일 정리
  rm -f $GZIP_FILE
  log_backup "임시 파일 정리 완료"
else
  log_backup "백업 실패!"
  echo "❌ 백업 실패!"
fi

log_backup "백업 작업 완료"
EOF

# 3. 실행 권한 부여
sudo chmod +x /usr/local/bin/db-backup.sh

# 4. 백업 테스트
sudo /usr/local/bin/db-backup.sh

log_message "DB 백업 스크립트 생성 완료"

# cron 작업 설정 (매일 아침 9시)
log_message "백업 cron 작업 설정 중..."
echo "0 9 * * * /usr/local/bin/db-backup.sh" | crontab -
log_message "백업 cron 작업 설정 완료"

# 환경 변수 파일 생성
log_message "DB 환경 변수 파일 생성 중..."
cat > /etc/db-config.env << EOF
DB_NAME=$DB_NAME
DB_USER=root
AWS_REGION=$AWS_REGION
DB_PASSWORD_SECRET_NAME=$DB_PASSWORD_SECRET_NAME
S3_BUCKET=$S3_BUCKET_NAME
EOF

# DB 복원 스크립트 생성 (풍부한 기능 버전)
log_message "DB 복원 스크립트 생성 중..."

cat > /usr/local/bin/db-restore.sh << 'EOF'
#!/bin/bash

# 환경 변수 파일 읽기
if [ -f /etc/db-config.env ]; then
  source /etc/db-config.env
fi

# AWS CLI 기본 리전 설정
aws configure set default.region $AWS_REGION

# Secrets Manager에서 비밀번호 가져오기
DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id $DB_PASSWORD_SECRET_NAME --region $AWS_REGION --query SecretString --output text)

# 복원 설정
RESTORE_DIR="/tmp/db-restore"
LOG_FILE="/tmp/db-restore.log"
FALLBACK_BACKUP="s3://pumati-dev-db-backup/tbdb_20250609_011839.sql.gz"

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로그 함수
log_restore() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

# 색상 출력 함수
print_success() {
  echo -e "${GREEN}✅ $1${NC}"
  log_restore "SUCCESS: $1"
}

print_error() {
  echo -e "${RED}❌ $1${NC}"
  log_restore "ERROR: $1"
}

print_warning() {
  echo -e "${YELLOW}⚠️  $1${NC}"
  log_restore "WARNING: $1"
}

print_info() {
  echo -e "${BLUE}ℹ️  $1${NC}"
  log_restore "INFO: $1"
}

# 사용법 함수
show_usage() {
  echo ""
  echo "🗃️  데이터베이스 복원 도구"
  echo "=============================="
  echo ""
  echo "사용법: $0 [옵션]"
  echo ""
  echo "📋 옵션:"
  echo "  -l, --list                    사용 가능한 백업 파일 목록 표시"
  echo "  -r, --latest                  최신 백업 파일로 복원"
  echo "  -f, --fallback                fallback 백업 파일로 복원"
  echo "  -s, --specific <filename>     특정 백업 파일로 복원"
  echo "  -i, --info <filename>         백업 파일 정보 표시"
  echo "  -h, --help                    이 도움말 표시"
  echo ""
  echo "📝 예시:"
  echo "  $0 --list"
  echo "  $0 --latest"
  echo "  $0 --specific tbdb-2025-06-02_09-00-01.sql.gz"
  echo "  $0 --fallback"
  echo "  $0 --info tbdb-2025-06-02_09-00-01.sql.gz"
  echo ""
}

# 백업 파일 목록 표시
list_backups() {
  print_info "S3에서 사용 가능한 백업 파일 목록을 조회합니다..."
  echo ""
  echo "📂 사용 가능한 백업 파일 목록"
  echo "================================"
  
  # S3에서 백업 파일 목록 가져오기
  aws s3 ls s3://$S3_BUCKET/backups/ --recursive | grep '\.sql\.gz$' | while read -r line; do
    date_time=$(echo $line | awk '{print $1, $2}')
    size=$(echo $line | awk '{print $3}')
    filename=$(echo $line | awk '{print $4}' | sed 's/backups\///')
    
    # 크기를 human readable로 변환
    if [ "$size" -gt 1073741824 ]; then
      size_hr="$(($size / 1073741824))GB"
    elif [ "$size" -gt 1048576 ]; then
      size_hr="$(($size / 1048576))MB"
    elif [ "$size" -gt 1024 ]; then
      size_hr="$(($size / 1024))KB"
    else
      size_hr="${size}B"
    fi
    
    echo "  📄 $filename"
    echo "     📅 생성일시: $date_time"
    echo "     📊 파일크기: $size_hr"
    echo ""
  done
  
  echo "🔄 fallback 백업 파일: tbdb_20250609_011839.sql.gz"
  echo ""
}

# 백업 파일 정보 표시
show_backup_info() {
  local backup_file="$1"
  
  print_info "백업 파일 정보 조회: $backup_file"
  
  # S3에서 파일 정보 가져오기
  aws s3 ls s3://$S3_BUCKET/backups/$backup_file --human-readable --summarize
  
  # 임시로 헤더만 다운로드해서 내용 확인
  mkdir -p $RESTORE_DIR
  aws s3 cp s3://$S3_BUCKET/backups/$backup_file $RESTORE_DIR/temp.sql.gz
  
  if [ -f "$RESTORE_DIR/temp.sql.gz" ]; then
    echo ""
    echo "📋 백업 파일 내용 미리보기:"
    echo "=========================="
    zcat $RESTORE_DIR/temp.sql.gz | head -20
    echo "..."
    echo ""
    echo "🗂️ 테이블 정보:"
    echo "=============="
    zcat $RESTORE_DIR/temp.sql.gz | grep "CREATE TABLE" | sed 's/CREATE TABLE /  📋 /' | sed 's/ (.*$//'
    
    rm -rf $RESTORE_DIR
  fi
}

# 데이터베이스 현재 상태 백업
backup_current_db() {
  print_info "복원 전 현재 데이터베이스 백업 생성 중..."
  
  local timestamp=$(date +%Y-%m-%d_%H-%M-%S)
  local backup_file="$RESTORE_DIR/pre-restore-backup-$timestamp.sql"
  
  mkdir -p $RESTORE_DIR
  
  mysqldump -u $DB_USER -p$DB_PASSWORD $DB_NAME > $backup_file 2>/dev/null
  
  if [ $? -eq 0 ]; then
    gzip $backup_file
    local backup_size=$(ls -lh $backup_file.gz | awk '{print $5}')
    print_success "현재 DB 백업 완료: $backup_file.gz ($backup_size)"
    
    # S3에도 업로드
    aws s3 cp $backup_file.gz s3://$S3_BUCKET/backups/pre-restore-$(basename $backup_file.gz) 2>/dev/null
    if [ $? -eq 0 ]; then
      print_info "현재 DB 백업을 S3에도 저장했습니다."
    fi
    
    return 0
  else
    print_error "현재 DB 백업 실패!"
    return 1
  fi
}

# 백업 파일 유효성 검사
validate_backup() {
  local backup_file="$1"
  
  print_info "백업 파일 유효성 검사 중: $backup_file"
  
  # 파일 존재 및 크기 확인
  if [ ! -f "$backup_file" ] || [ ! -s "$backup_file" ]; then
    print_error "백업 파일이 존재하지 않거나 비어있습니다."
    return 1
  fi
  
  # gzip 파일 무결성 확인
  if ! gunzip -t "$backup_file" 2>/dev/null; then
    print_error "백업 파일이 손상되었습니다."
    return 1
  fi
  
  # SQL 파일 기본 구조 확인
  if ! zcat "$backup_file" | head -10 | grep -q "MySQL dump"; then
    print_error "올바른 MySQL 덤프 파일이 아닙니다."
    return 1
  fi
  
  print_success "백업 파일 유효성 검사 통과"
  return 0
}

# 복원 진행 상황 표시
show_restore_progress() {
  local sql_file="$1"
  local total_lines=$(wc -l < "$sql_file")
  
  print_info "복원 진행 중... (총 $total_lines 라인)"
  
  # MySQL 복원을 백그라운드에서 실행하면서 진행률 표시
  mysql -u $DB_USER -p$DB_PASSWORD $DB_NAME < "$sql_file" &
  local mysql_pid=$!
  
  while kill -0 $mysql_pid 2>/dev/null; do
    echo -n "."
    sleep 2
  done
  
  wait $mysql_pid
  return $?
}

# 복원 후 검증
verify_restore() {
  print_info "복원 결과 검증 중..."
  
  # 테이블 수 확인
  local table_count=$(mysql -u $DB_USER -p$DB_PASSWORD $DB_NAME -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$DB_NAME';" 2>/dev/null | tail -n 1)
  
  if [ -n "$table_count" ] && [ "$table_count" -gt 0 ]; then
    print_success "복원된 테이블 수: $table_count"
    
    echo ""
    echo "📋 복원된 테이블 목록:"
    echo "===================="
    mysql -u $DB_USER -p$DB_PASSWORD $DB_NAME -e "SHOW TABLES;" 2>/dev/null | tail -n +2 | while read table; do
      local row_count=$(mysql -u $DB_USER -p$DB_PASSWORD $DB_NAME -e "SELECT COUNT(*) FROM \`$table\`;" 2>/dev/null | tail -n 1)
      echo "  📄 $table ($row_count rows)"
    done
    
    return 0
  else
    print_error "복원 검증 실패: 테이블이 없습니다."
    return 1
  fi
}

# 백업 파일 복원
restore_backup() {
  local backup_source="$1"
  local backup_file="$2"
  
  print_info "백업 파일 복원 시작"
  echo "====================="
  echo "📁 복원 소스: $backup_source"
  echo "📄 백업 파일: $backup_file"
  echo ""
  
  # 복원 디렉터리 생성
  mkdir -p $RESTORE_DIR
  cd $RESTORE_DIR
  
  # 현재 DB 백업 (선택사항)
  echo "현재 데이터베이스를 백업하시겠습니까? (권장) [Y/n]: "
  read -r backup_confirm
  if [[ ! $backup_confirm =~ ^[Nn]$ ]]; then
    if ! backup_current_db; then
      print_warning "현재 DB 백업 실패. 계속 진행하시겠습니까? [y/N]: "
      read -r continue_confirm
      if [[ ! $continue_confirm =~ ^[Yy]$ ]]; then
        print_info "복원 작업이 취소되었습니다."
        return 1
      fi
    fi
  fi
  
  # 백업 파일 다운로드
  case "$backup_source" in
    "s3")
      print_info "S3에서 백업 파일 다운로드 중: s3://$S3_BUCKET/$backup_file"
      aws s3 cp s3://$S3_BUCKET/$backup_file . 2>>$LOG_FILE
      local downloaded_file=$(basename "$backup_file")
      ;;
    "fallback")
      print_info "fallback 백업 파일 다운로드 중"
      aws s3 cp $FALLBACK_BACKUP ./fallback-backup.sql.gz 2>>$LOG_FILE
      local downloaded_file="fallback-backup.sql.gz"
      ;;
  esac
  
  # 다운로드 확인 및 유효성 검사
  if ! validate_backup "$downloaded_file"; then
    print_error "백업 파일 검증 실패!"
    return 1
  fi
  
  local backup_size=$(ls -lh $downloaded_file | awk '{print $5}')
  print_success "백업 파일 다운로드 완료: $downloaded_file ($backup_size)"
  
  # 압축 해제
  print_info "백업 파일 압축 해제 중..."
  gunzip -f $downloaded_file 2>>$LOG_FILE
  
  if [ $? -ne 0 ]; then
    print_error "백업 파일 압축 해제 실패!"
    return 1
  fi
  
  local sql_file=$(echo $downloaded_file | sed 's/\.gz$//')
  print_success "압축 해제 완료: $sql_file"
  
  # 데이터베이스 재생성 확인
  echo ""
  print_warning "주의: 기존 데이터베이스가 완전히 삭제되고 재생성됩니다!"
  echo "계속 진행하시겠습니까? [y/N]: "
  read -r final_confirm
  if [[ ! $final_confirm =~ ^[Yy]$ ]]; then
    print_info "복원 작업이 취소되었습니다."
    return 1
  fi
  
  # 기존 데이터베이스 삭제 및 재생성
  print_info "기존 데이터베이스 재생성 중..."
  mysql -u $DB_USER -p$DB_PASSWORD <<EOSQL 2>>$LOG_FILE
DROP DATABASE IF EXISTS $DB_NAME;
CREATE DATABASE $DB_NAME;
EOSQL
  
  if [ $? -ne 0 ]; then
    print_error "데이터베이스 재생성 실패!"
    return 1
  fi
  
  print_success "데이터베이스 재생성 완료"
  
  # 데이터베이스 복원
  print_info "데이터베이스 복원 실행 중..."
  echo "이 작업은 시간이 걸릴 수 있습니다..."
  
  if show_restore_progress "$sql_file"; then
    echo ""
    print_success "데이터베이스 복원 완료!"
    
    # 복원 검증
    if verify_restore; then
      print_success "복원 검증 완료!"
    else
      print_warning "복원 검증에서 일부 문제가 발견되었습니다."
    fi
  else
    print_error "데이터베이스 복원 실패!"
    return 1
  fi
  
  # 임시 파일 정리
  print_info "임시 파일 정리 중..."
  cd /
  rm -rf $RESTORE_DIR
  
  print_success "데이터베이스 복원 작업이 성공적으로 완료되었습니다! 🎉"
  echo ""
}

# 메인 로직
case "$1" in
  -l|--list)
    list_backups
    ;;
  -r|--latest)
    print_info "최신 백업 파일로 복원을 시작합니다..."
    LATEST_BACKUP=$(aws s3 ls s3://$S3_BUCKET/backups/ --recursive | grep '\.sql\.gz$' | sort | tail -n 1 | awk '{print $4}')
    if [ -z "$LATEST_BACKUP" ]; then
      print_error "최신 백업 파일을 찾을 수 없습니다."
      exit 1
    fi
    restore_backup "s3" "$LATEST_BACKUP"
    ;;
  -s|--specific)
    if [ -z "$2" ]; then
      print_error "백업 파일명을 지정해주세요."
      show_usage
      exit 1
    fi
    print_info "지정된 백업 파일로 복원을 시작합니다: $2"
    restore_backup "s3" "backups/$2"
    ;;
  -f|--fallback)
    print_info "fallback 백업 파일로 복원을 시작합니다..."
    restore_backup "fallback" ""
    ;;
  -i|--info)
    if [ -z "$2" ]; then
      print_error "백업 파일명을 지정해주세요."
      show_usage
      exit 1
    fi
    show_backup_info "$2"
    ;;
  -h|--help)
    show_usage
    ;;
  "")
    print_error "옵션을 지정해주세요."
    show_usage
    exit 1
    ;;
  *)
    print_error "알 수 없는 옵션: $1"
    show_usage
    exit 1
    ;;
esac
EOF

chmod +x /usr/local/bin/db-restore.sh
log_message "DB 복원 스크립트 생성 완료"

log_message "완료: DB 서버 설정 스크립트"