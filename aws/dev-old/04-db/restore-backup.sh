#!/bin/bash

# 로그 파일 설정
LOGFILE="/var/log/db-restore.log"

# 로그 기록 함수
log_message() {
  local message="$1"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] $message" | tee -a $LOGFILE
}

# 기본 변수 설정
DB_NAME="tbdb"
DB_USER="root"
BACKUP_DIR="/tmp/db-restore"
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)

# 사용법 함수
usage() {
  echo "사용법: $0 [옵션]"
  echo "옵션:"
  echo "  -b, --bucket BUCKET_NAME   S3 버킷 이름 (필수)"
  echo "  -f, --file FILE_NAME       복원할 백업 파일 이름 (필수)"
  echo "  -p, --password PASSWORD    MySQL 비밀번호 (필수)"
  echo "  -h, --help                 도움말 표시"
  exit 1
}

# 명령행 인자 파싱
while [[ $# -gt 0 ]]; do
  case $1 in
    -b|--bucket)
      S3_BUCKET="$2"
      shift 2
      ;;
    -f|--file)
      BACKUP_FILE="$2"
      shift 2
      ;;
    -p|--password)
      DB_PASSWORD="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "알 수 없는 옵션: $1"
      usage
      ;;
  esac
done

# 필수 인자 확인
if [ -z "$S3_BUCKET" ] || [ -z "$BACKUP_FILE" ] || [ -z "$DB_PASSWORD" ]; then
  echo "오류: 필수 인자가 누락되었습니다."
  usage
fi

log_message "시작: MySQL 데이터베이스 백업 복원 스크립트"

# 작업 디렉토리 생성
mkdir -p $BACKUP_DIR
cd $BACKUP_DIR

# S3에서 백업 파일 다운로드
log_message "S3에서 백업 파일 다운로드 중: s3://$S3_BUCKET/backups/$BACKUP_FILE"
aws s3 cp s3://$S3_BUCKET/backups/$BACKUP_FILE . >> $LOGFILE 2>&1

if [ $? -ne 0 ]; then
  log_message "오류: S3에서 백업 파일 다운로드 실패!"
  exit 1
fi

log_message "백업 파일 다운로드 완료: $BACKUP_FILE"

# 압축 해제 (파일이 .gz로 끝나는 경우)
if [[ $BACKUP_FILE == *.gz ]]; then
  log_message "백업 파일 압축 해제 중..."
  gunzip -f $BACKUP_FILE
  if [ $? -ne 0 ]; then
    log_message "오류: 백업 파일 압축 해제 실패!"
    exit 1
  fi
  # .gz 확장자 제거
  SQL_FILE="${BACKUP_FILE%.gz}"
else
  SQL_FILE=$BACKUP_FILE
fi

log_message "압축 해제 완료: $SQL_FILE"

# 기존 데이터베이스 백업 (안전 조치)
log_message "기존 데이터베이스 백업 중..."
mysqldump -u $DB_USER -p$DB_PASSWORD $DB_NAME > ${DB_NAME}_before_restore_${TIMESTAMP}.sql 2>> $LOGFILE
if [ $? -ne 0 ]; then
  log_message "경고: 기존 데이터베이스 백업 실패! 복원 작업을 계속하시겠습니까? (y/n)"
  read -p "계속하시겠습니까? (y/n): " confirm
  if [[ $confirm != [yY] ]]; then
    log_message "사용자에 의해 복원 작업 취소됨"
    exit 1
  fi
fi

# 데이터베이스 복원
log_message "데이터베이스 복원 중..."
mysql -u $DB_USER -p$DB_PASSWORD $DB_NAME < $SQL_FILE 2>> $LOGFILE

if [ $? -ne 0 ]; then
  log_message "오류: 데이터베이스 복원 실패!"
  log_message "백업 파일을 확인하고 다시 시도하세요."
  exit 1
fi

log_message "데이터베이스 복원 완료!"

# 임시 파일 정리
log_message "임시 파일 정리 중..."
cd /
rm -rf $BACKUP_DIR
log_message "임시 파일 정리 완료"

log_message "완료: MySQL 데이터베이스 백업 복원 스크립트"
echo "데이터베이스 복원이 성공적으로 완료되었습니다!" 