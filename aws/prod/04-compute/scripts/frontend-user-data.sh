#!/bin/bash
set -eux

# -----------------------------
# [1] 시스템 패키지 업데이트
# -----------------------------
sudo apt update && sudo apt upgrade -y

# -----------------------------
# [2] Node.js 23 설치 + npm
# -----------------------------
curl -fsSL https://deb.nodesource.com/setup_23.x | sudo -E bash -
sudo apt-get install -y nodejs
command -v npm >/dev/null 2>&1 || sudo apt-get install -y npm
sudo npm install -g pnpm

# -----------------------------
# [3] Docker 설치
# -----------------------------
sudo apt remove -y docker docker-engine docker.io containerd runc || true
sudo apt install -y ca-certificates curl gnupg lsb-release unzip
sudo install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker ubuntu

# -----------------------------
# [4] AWS CLI v2 설치
# -----------------------------
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf awscliv2.zip aws/

# -----------------------------
# [5] ECR 로그인 & 이미지 실행
# -----------------------------
AWS_REGION="ap-northeast-2"
ECR_REPO="236450698266.dkr.ecr.ap-northeast-2.amazonaws.com/pumati-prod-frontend-ecr"
ECR_TAG="frontend-17"

aws ecr get-login-password --region ${AWS_REGION} | \
  sudo docker login --username AWS --password-stdin ${ECR_REPO}

sudo docker pull ${ECR_REPO}:${ECR_TAG}

sudo docker run -d --name frontend-test -p 3000:3000 ${ECR_REPO}:${ECR_TAG}

# -----------------------------
# [6] Nginx 설치 및 설정
# -----------------------------
sudo apt install -y nginx
sudo systemctl enable nginx
sudo systemctl start nginx

sudo tee /etc/nginx/sites-available/tebutebu.com > /dev/null <<'EOF'
server {
    server_name tebutebu.com;

    location /api/ {
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_pass http://10.3.0.107:8080;
    }

    location /oauth2/ {
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_pass http://10.3.0.107:8080;
    }

    location / {
        proxy_pass http://localhost:3000/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/tebutebu.com/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/tebutebu.com/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot
}

server {
    if ($host = tebutebu.com) {
        return 301 https://$host$request_uri;
    } # managed by Certbot

    listen 80;
    server_name tebutebu.com;
    return 404; # managed by Certbot
}
EOF

sudo ln -sf /etc/nginx/sites-available/tebutebu.com /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
