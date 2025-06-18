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

# [3-7] 현재 사용자에게 Docker 그룹 권한 부여
sudo usermod -aG docker ubuntu
# ubuntu 사용자가 Docker를 사용하려면 재로그인이 필요

# -----------------------------
# [4] AWS CLI 설치
# -----------------------------
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -o awscliv2.zip

# 이전 설치 디렉토리 정리 (이미 존재하는 경우 대비)
sudo rm -rf /usr/local/aws-cli
sudo ./aws/install

# [4-1] aws 명령어를 /usr/bin에도 연결 (PATH 문제 방지)
sudo ln -s /usr/local/bin/aws /usr/bin/aws || true

# [4-2] ubuntu 사용자에게 AWS CLI 경로 추가
echo 'export PATH=$PATH:/usr/local/bin' >> /home/ubuntu/.bashrc
chown ubuntu:ubuntu /home/ubuntu/.bashrc

# AWS CLI 버전 확인
/usr/local/bin/aws --version

# -----------------------------
# [5] 정리 작업
# -----------------------------
rm -rf awscliv2.zip aws

echo "==============================================="
echo "[알림] 초기 셋업 완료되었습니다."
echo "[주의] 'ubuntu' 사용자가 Docker 그룹 권한을 사용하려면 재로그인이 필요합니다."
echo "다음 명령을 입력하거나, SSH를 다시 접속해주세요:"
echo "  newgrp docker"
echo ""
echo "[주의] AWS CLI를 사용하려면 다음 명령으로 경로가 잘 설정됐는지 확인하세요:"
echo "  source /home/ubuntu/.bashrc && aws --version"
echo "==============================================="