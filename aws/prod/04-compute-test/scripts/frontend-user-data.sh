#!/bin/bash
set -eux  # 에러 발생 시 중단, 변수 미정의 시 중단, 실행 명령 출력

# -----------------------------
# [1] 시스템 업데이트 및 필수 패키지 설치
# -----------------------------
sudo apt update && sudo apt upgrade -y
sudo apt install -y gnupg ca-certificates curl lsb-release unzip

# -----------------------------
# [2] Docker 설치
# -----------------------------
sudo apt remove -y docker docker-engine docker.io containerd runc || true
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

sudo systemctl enable docker
sudo systemctl start docker

# ubuntu 사용자에게 Docker 그룹 권한 부여
sudo usermod -aG docker ubuntu

# -----------------------------
# [3] AWS CLI 설치
# -----------------------------
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -o awscliv2.zip
sudo rm -rf /usr/local/aws-cli
sudo ./aws/install

# /usr/bin 경로에 aws 링크 추가 (PATH 이슈 방지)
sudo ln -s /usr/local/bin/aws /usr/bin/aws || true

# ubuntu 사용자의 .bashrc에 AWS CLI 경로 추가
echo 'export PATH=$PATH:/usr/local/bin' >> /home/ubuntu/.bashrc
chown ubuntu:ubuntu /home/ubuntu/.bashrc

# -----------------------------
# [4] 정리 작업
# -----------------------------
rm -rf awscliv2.zip aws

# -----------------------------
# [5] 안내 메시지
# -----------------------------
echo "==============================================="
echo "[알림] 프론트엔드 인스턴스 초기 셋업 완료"
echo "[주의] 'ubuntu' 사용자가 Docker 그룹 권한을 사용하려면 재로그인이 필요합니다."
echo "다음 명령을 입력하거나, SSH를 다시 접속해주세요:"
echo "  newgrp docker"
echo ""
echo "[주의] AWS CLI를 사용하려면 다음 명령으로 경로가 잘 설정됐는지 확인하세요:"
echo "  source /home/ubuntu/.bashrc && aws --version"
echo "==============================================="
