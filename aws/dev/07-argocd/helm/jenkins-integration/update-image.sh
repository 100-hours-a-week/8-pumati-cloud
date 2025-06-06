#!/bin/bash

# Jenkins에서 ArgoCD 애플리케이션의 이미지 태그를 업데이트하는 스크립트
# 사용법: ./update-image.sh <app-name> <new-image-tag>

set -e

# 파라미터 검증
if [ $# -ne 2 ]; then
    echo "사용법: $0 <app-name> <new-image-tag>"
    echo "예시: $0 pumati-frontend v1.2.3"
    exit 1
fi

APP_NAME=$1
NEW_TAG=$2
ARGOCD_SERVER="argocd.pumati.example.com"  # 실제 도메인으로 변경 필요
ARGOCD_USERNAME="admin"
ARGOCD_PASSWORD="${ARGOCD_PASSWORD:-password}"  # 환경변수에서 가져오거나 기본값 사용

echo "=== ArgoCD 애플리케이션 이미지 태그 업데이트 ==="
echo "애플리케이션: $APP_NAME"
echo "새 이미지 태그: $NEW_TAG"
echo "ArgoCD 서버: $ARGOCD_SERVER"

# ArgoCD CLI 로그인
echo "ArgoCD에 로그인 중..."
argocd login $ARGOCD_SERVER \
    --username $ARGOCD_USERNAME \
    --password $ARGOCD_PASSWORD \
    --insecure

# 애플리케이션 이미지 태그 업데이트
echo "이미지 태그 업데이트 중..."
argocd app set $APP_NAME \
    --parameter image.tag=$NEW_TAG

# 애플리케이션 동기화 트리거
echo "애플리케이션 동기화 중..."
argocd app sync $APP_NAME

# 동기화 상태 확인
echo "동기화 상태 확인 중..."
argocd app wait $APP_NAME --timeout 300

echo "=== 이미지 태그 업데이트 완료 ==="
echo "애플리케이션 $APP_NAME이 이미지 태그 $NEW_TAG로 성공적으로 업데이트되었습니다."

# 애플리케이션 상태 출력
argocd app get $APP_NAME 