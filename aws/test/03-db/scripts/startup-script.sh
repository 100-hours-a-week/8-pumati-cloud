#!/bin/bash

# 로그 설정
LOGFILE="/var/log/user-data.log"
log_message() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOGFILE
}

log_message "User Data 시작: S3에서 DB startup script 다운로드 및 실행"

# AWS CLI 설정
aws configure set default.region ${aws_region}

# 환경변수 설정 (Terraform에서 전달받음)
export PROJECT_NAME="${project_name}"
export ENVIRONMENT="${environment}"
export DB_NAME="${db_name}"
export DB_USERNAME="${db_username}"
export DB_PASSWORD_SECRET_NAME="${db_password_secret_name}"
export S3_BUCKET_NAME="${s3_bucket_name}"
export AWS_REGION="${aws_region}"

log_message "환경변수 설정 완료"
log_message "PROJECT_NAME: $PROJECT_NAME"
log_message "DB_NAME: $DB_NAME"
log_message "DB_USERNAME: $DB_USERNAME"

# S3에서 startup script 다운로드
log_message "S3에서 DB startup script 다운로드 중..."
aws s3 cp s3://${s3_bucket_name}/scripts/db-script.sh /tmp/db-script.sh

if [ $? -eq 0 ]; then
    log_message "DB startup script 다운로드 완료"
    
    # 실행 권한 부여 및 실행
    chmod +x /tmp/db-script.sh
    log_message "DB startup script 실행 시작"
    /tmp/db-script.sh
    log_message "DB startup script 실행 완료"
else
    log_message "오류: DB startup script 다운로드 실패!"
fi

log_message "User Data 완료"