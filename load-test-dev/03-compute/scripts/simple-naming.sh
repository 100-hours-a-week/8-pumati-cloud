#!/bin/bash
# 간단한 인스턴스 이름 설정 방법 (대안)

# 방법 1: 인스턴스 ID 기반 간단 번호
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
SIMPLE_NUMBER=$(echo $INSTANCE_ID | tail -c 3)  # 마지막 2글자로 번호 생성
NEW_NAME="backend-$SIMPLE_NUMBER"

# 방법 2: 타임스탬프 기반 번호
TIMESTAMP=$(date +%s)
UNIQUE_NUMBER=$(echo $TIMESTAMP | tail -c 3)
NEW_NAME="backend-$UNIQUE_NUMBER"

# 방법 3: Private IP 기반 번호
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
IP_SUFFIX=$(echo $PRIVATE_IP | cut -d'.' -f4)  # IP 마지막 옥텟 사용
NEW_NAME="backend-$IP_SUFFIX"

# EC2 태그 적용
aws ec2 create-tags \
  --region ap-northeast-2 \
  --resources $INSTANCE_ID \
  --tags Key=Name,Value=$NEW_NAME

echo "인스턴스 이름: $NEW_NAME" 