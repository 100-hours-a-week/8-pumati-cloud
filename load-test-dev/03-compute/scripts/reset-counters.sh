#!/bin/bash
# 인스턴스 번호 카운터 초기화 스크립트

BUCKET_NAME="8-ktb-chat-tfstate"

echo "=== 인스턴스 번호 카운터 초기화 ==="

# 백엔드 카운터 초기화
echo "0" | aws s3 cp - s3://$BUCKET_NAME/load-test/backend-counter.txt
echo "✅ 백엔드 카운터 초기화 완료"

# 프론트엔드 카운터 초기화
echo "0" | aws s3 cp - s3://$BUCKET_NAME/load-test/frontend-counter.txt
echo "✅ 프론트엔드 카운터 초기화 완료"

echo ""
echo "다음 인스턴스들은 backend-1, backend-2, frontend-1, frontend-2 순서로 이름이 부여됩니다."

# 현재 카운터 상태 확인
echo ""
echo "=== 현재 카운터 상태 ==="
echo -n "백엔드 카운터: "
aws s3 cp s3://$BUCKET_NAME/load-test/backend-counter.txt - 2>/dev/null || echo "0 (초기값)"
echo -n "프론트엔드 카운터: "
aws s3 cp s3://$BUCKET_NAME/load-test/frontend-counter.txt - 2>/dev/null || echo "0 (초기값)" 