#!/bin/bash
set -eux  # 에러 발생 시 중단(-e), 변수 미정의 시 중단(-u), 실행 명령 출력(-x)

# -----------------------------
# [1] 시스템 업데이트 및 필수 패키지 설치
# -----------------------------
sudo apt update && sudo apt upgrade -y
sudo apt install -y gnupg ca-certificates curl lsb-release unzip

# -----------------------------
# [2] OpenJDK 21 설치
# -----------------------------
sudo apt install -y openjdk-21-jdk
java -version

# -----------------------------
# [3] Docker 설치
# -----------------------------

# 3-1. 기존 Docker 제거 (있다면)
sudo apt remove -y docker docker-engine docker.io containerd runc || true

# 3-2. Docker GPG 키 디렉토리 생성
sudo install -m 0755 -d /etc/apt/keyrings

# 3-3. Docker GPG 키 추가
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# 3-4. Docker 저장소 등록
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 3-5. Docker 설치
sudo apt install -y docker-ce docker-ce-cli containerd.io

# 3-6. Docker 데몬 자동 시작 설정
sudo systemctl enable docker
sudo systemctl start docker

# 3-7. 현재 사용자에게 Docker 그룹 권한 부여
sudo usermod -aG docker $USER || true

# -----------------------------
# [4] AWS CLI 설치
# -----------------------------
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version

# -----------------------------
# [5] 정리 작업
# -----------------------------
rm -rf awscliv2.zip aws
