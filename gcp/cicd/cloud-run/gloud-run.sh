#!/bin/bash

# === 사용자 설정 ===
PROJECT_ID="ktb8team-458916"
REGION="asia-southeast1"    # 여기만 됨.
REPOSITORY="ktb8team-docker-repo"
IMAGE_NAME="pumati-cloud-run"   # docker로 만든 이미지 이름. 아티팩트 레지스트리에 있음
SERVICE_NAME="pumati-cloud-run"
SERVICE_ACCOUNT="terraform@${PROJECT_ID}.iam.gserviceaccount.com"  # 테라폼용으로 만든 서비스 계정

# === 배포 명령 ===
# TODO: --no-allow-unauthenticated 로 변경 필요
# 마지막에 --no-gpu-zonal-redundancy 필수임. 안그럼 할당량 없다고 안됨
gcloud beta run deploy "$SERVICE_NAME" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --image="$REGION-docker.pkg.dev/$PROJECT_ID/$REPOSITORY/$IMAGE_NAME:latest" \
  --concurrency=4 \
  --cpu=8 \
  --memory=32Gi \
  --gpu=1 \
  --gpu-type=nvidia-l4 \
  --max-instances=3 \
  --timeout=600 \
  --allow-unauthenticated \
  --no-cpu-throttling \
  --service-account="$SERVICE_ACCOUNT" \
  --set-env-vars=OLLAMA_NUM_PARALLEL=4 \
  --no-gpu-zonal-redundancy
