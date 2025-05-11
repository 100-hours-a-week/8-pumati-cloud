#!/bin/bash

LOGFILE="/var/log/startup-script.log"
log_message() {
  local message="$1"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] $message" | tee -a $LOGFILE
  logger -t startup-script "$message"
}

log_message "✅ [시작] 스타트업 스크립트 실행 - 호스트명: $(hostname)"

# 시스템 패키지 업데이트
log_message "▶ 시스템 패키지 업데이트 중..."
if apt-get update && apt-get upgrade -y; then
  log_message "✅ 시스템 패키지 업데이트 완료"
else
  log_message "⚠️ 시스템 패키지 업데이트 중 일부 오류 발생, 계속 진행합니다"
fi

##########################
# 1. NVIDIA 드라이버 설치
##########################
log_message "▶ NVIDIA 드라이버 및 CUDA는 이미 딥러닝 VM 이미지에 설치되어 있음"
# 설치 확인
if nvidia-smi &> /dev/null; then
  log_message "✅ NVIDIA 드라이버 확인 완료"
else
  log_message "❌ NVIDIA 드라이버 확인 실패! 시스템에 설치되지 않았거나 문제가 있습니다."
  # Discord로 알림 전송
  curl -H "Content-Type: application/json" \
       -X POST \
       -d '{"content": "🚨 NVIDIA 드라이버 문제 발생: GPU를 사용할 수 없습니다."}' \
       "${WEBHOOK_URL}"
fi

#####################################
# 2. 종료 감지 → Discord 알림 전송
#####################################
log_message "▶ 프리엠션 감지 스크립트 설정 중..."
cat <<EOF > /opt/detect-preemption.sh
#!/bin/bash
while true; do
  PREEMPTED=\$(curl -s -f -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/preempted 2>/dev/null)
  if [[ "\$PREEMPTED" == "TRUE" ]]; then
    curl -H "Content-Type: application/json" \
         -X POST \
         -d '{"content": "🚨 GCP 스팟 인스턴스가 중단(preempt)됩니다. 약 30초 내 종료 예정입니다."}' \
         "${WEBHOOK_URL}"
    break
  fi
  sleep 5
done
EOF
chmod +x /opt/detect-preemption.sh
nohup /opt/detect-preemption.sh > /var/log/preempt.log 2>&1 &
log_message "✅ 프리엠션 감지 스크립트 백그라운드 실행 완료"

################################
# 3. cloudflared 설치 및 설정
################################
log_message "▶ cloudflared 설치 시작"
cd /tmp
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb

# 설치 시도 및 결과 확인
if dpkg -i cloudflared-linux-amd64.deb; then
  log_message "✅ cloudflared 패키지 설치 성공"
else
  log_message "❌ cloudflared 패키지 설치 실패, 수동 설치 시도"
  
  # 바이너리 직접 다운로드 및 설치 (대안)
  wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O cloudflared
  chmod +x cloudflared
  mv cloudflared /usr/local/bin/cloudflared
  
  # 실행 파일 링크 생성
  ln -sf /usr/local/bin/cloudflared /usr/bin/cloudflared
  
  log_message "✅ cloudflared 바이너리 수동 설치 완료"
fi

# 설치 확인
if ! command -v cloudflared &> /dev/null; then
  log_message "❌ cloudflared 설치 실패: 실행 파일을 찾을 수 없음"
  curl -H "Content-Type: application/json" \
       -X POST \
       -d '{"content": "🚨 cloudflared 설치 실패: 서버 $(hostname)에서 cloudflared를 설치하지 못했습니다."}' \
       "${WEBHOOK_URL}"
  exit 1
fi

log_message "▶ cloudflared 디렉토리 생성 중"
mkdir -p /etc/cloudflared /root/.cloudflared /var/log/cloudflared

log_message "▶ cloudflared 인증 파일 GCS에서 다운로드 중"
gsutil cp gs://ktb8team-static-storage-dev/cloudflare/${TUNNEL_UUID}.json /etc/cloudflared/llm-tunnel.json
gsutil cp gs://ktb8team-static-storage-dev/cloudflare/cert.pem /root/.cloudflared/cert.pem

log_message "▶ config.yml 설정 파일 생성"
cat <<EOF > /etc/cloudflared/config.yml
tunnel: ${TUNNEL_UUID}
credentials-file: /etc/cloudflared/llm-tunnel.json

ingress:
  - hostname: ai.mydairy.my
    service: http://localhost:8000
  - service: http_status:404
EOF

# cloudflared 경로 확인 및 서비스 파일에 올바른 경로 사용
CLOUDFLARED_PATH=$(which cloudflared)
log_message "▶ 감지된 cloudflared 경로: $CLOUDFLARED_PATH"

log_message "▶ cloudflared systemd 서비스 파일 생성"
cat <<EOF > /etc/systemd/system/cloudflared.service
[Unit]
Description=Cloudflare Tunnel
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=$CLOUDFLARED_PATH tunnel --config /etc/cloudflared/config.yml run
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable cloudflared
systemctl start cloudflared

# 서비스 상태 확인
if systemctl is-active --quiet cloudflared; then
  log_message "✅ cloudflared 터널 서비스 시작 완료"
else
  log_message "❌ cloudflared 서비스 시작 실패"
  systemctl status cloudflared
  journalctl -u cloudflared --no-pager -n 20
  
  # 실패 알림 전송
  curl -H "Content-Type: application/json" \
       -X POST \
       -d '{"content": "🚨 cloudflared 서비스 시작 실패: 서버 $(hostname)에서 cloudflared 서비스를 시작하지 못했습니다."}' \
       "${WEBHOOK_URL}"
fi

##################################
# 4. Docker 설정 (이미 설치됨)
##################################
log_message "▶ Docker 및 NVIDIA Container Toolkit은 이미 딥러닝 VM 이미지에 설치되어 있음"
# 설정 확인
if docker info | grep -i nvidia &> /dev/null; then
  log_message "✅ Docker NVIDIA 설정 확인 완료 - GPU 사용 가능"
else
  log_message "❌ Docker에서 NVIDIA 런타임을 찾을 수 없습니다. GPU 컨테이너 실행이 불가능할 수 있습니다."
  # Discord로 알림 전송
  curl -H "Content-Type: application/json" \
       -X POST \
       -d '{"content": "🚨 Docker NVIDIA 설정 문제: 서버 $(hostname)에서 Docker가 GPU를 인식하지 못합니다."}' \
       "${WEBHOOK_URL}"
fi

###################################
# 6. 모니터링 에이전트 설치
###################################
log_message "▶ 모니터링 에이전트 설치 시작"

# 작업 디렉토리 생성
mkdir -p /opt/monitoring
cd /opt/monitoring

# 1. NVIDIA DCGM Exporter 설치 - GPU 메트릭 수집
log_message "▶ NVIDIA DCGM Exporter 실행 중..."
docker run -d --restart=unless-stopped \
  --name dcgm-exporter \
  --gpus all \
  -p 9400:9400 \
  -e DCGM_EXPORTER_COLLECTORS=gpu_utilization,gpu_memory,gpu_temperature,gpu_power,gpu_accounting \
  nvidia/dcgm-exporter:latest

# 2. Node Exporter 설치 - 시스템 메트릭 수집
log_message "▶ Node Exporter 실행 중..."
docker run -d --restart=unless-stopped \
  --name node-exporter \
  -p 9100:9100 \
  -v "/proc:/host/proc:ro" \
  -v "/sys:/host/sys:ro" \
  -v "/:/rootfs:ro" \
  prom/node-exporter:latest \
  --path.procfs=/host/proc \
  --path.sysfs=/host/sys \
  --collector.filesystem.ignored-mount-points="^/(sys|proc|dev|host|etc)($$|/)"

# 3. Loki 에이전트 (Promtail) 설정 - 로그 수집
# 참고: 이 부분은 외부 Loki 서버가 있을 때 주석을 해제하여 사용
log_message "▶ Promtail 설정 파일 작성 중..."
cat <<EOL > promtail-config.yml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

# Loki 서버 정보 - 외부 Loki 서버 URL로 변경 필요
clients:
  - url: http://YOUR_LOKI_SERVER:3100/loki/api/v1/push

scrape_configs:
  # 시스템 로그 수집
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          host: $HOSTNAME
          __path__: /var/log/*log

  # GPU 관련 로그 수집
  - job_name: gpu_logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: gpu_logs
          host: $HOSTNAME
          __path__: /var/log/nvidia-smi.log

  # Docker 로그 수집
  - job_name: docker
    static_configs:
      - targets:
          - localhost
        labels:
          job: docker
          host: $HOSTNAME
          __path__: /var/lib/docker/containers/*/*.log

  # 애플리케이션 로그 수집
  - job_name: pumati_app
    static_configs:
      - targets:
          - localhost
        labels:
          job: pumati_app
          host: $HOSTNAME
          __path__: /opt/ai-app/logs/*.log
EOL

# Promtail 실행 설정 (주석 처리됨 - Loki 서버 설정 후 주석 해제 필요)
log_message "▶ Promtail 실행 명령 (주석 처리됨)"
log_message "   주의: 외부 Loki 서버 URL을 설정한 후 아래 명령어의 주석을 해제하세요"
log_message "   docker run -d --restart=unless-stopped \\"
log_message "     --name promtail \\"
log_message "     -v \"/var/log:/var/log\" \\"
log_message "     -v \"/opt/ai-app/logs:/opt/logs\" \\"
log_message "     -v \"\$(pwd)/promtail-config.yml:/etc/promtail/config.yml\" \\"
log_message "     grafana/promtail:latest \\"
log_message "     -config.file=/etc/promtail/config.yml"

# Loki 서버 설정 방법에 대한 안내
cat <<EOH > loki-setup-guide.txt
# Loki 서버 설정 방법

## 1. 독립 VM에 Loki 서버 설치하기
```bash
# Loki 설치
docker run -d --name=loki -p 3100:3100 \
  -v /opt/loki:/etc/loki \
  --restart=unless-stopped \
  grafana/loki:latest \
  -config.file=/etc/loki/local-config.yaml

# Grafana 설치 (선택사항)
docker run -d --name=grafana -p 3000:3000 \
  --restart=unless-stopped \
  grafana/grafana:latest
```

## 2. Promtail 활성화 방법
1. promtail-config.yml 파일에서 아래 부분을 수정:
   ```yaml
   clients:
     - url: http://YOUR_LOKI_SERVER_IP:3100/loki/api/v1/push
   ```

2. 주석 처리된 docker run 명령어의 주석을 해제하고 실행

## 3. Grafana에서 Loki 데이터소스 추가
1. Grafana에 접속 (http://GRAFANA_IP:3000)
2. Configuration > Data Sources > Add data source
3. Loki 선택
4. URL에 http://LOKI_SERVER_IP:3100 입력
5. Save & Test
EOH

log_message "✅ Loki 설정 가이드가 /opt/monitoring/loki-setup-guide.txt에 저장되었습니다"

# 3. GCP Ops Agent 설치 (Cloud Monitoring 연동)
log_message "▶ GCP Ops Agent 설치 중..."
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
bash add-google-cloud-ops-agent-repo.sh --also-install

# 4. Ops Agent 설정 파일 생성 (GPU 메트릭 수집용)
log_message "▶ Ops Agent GPU 모니터링 설정 중..."
cat <<EOG > /etc/google-cloud-ops-agent/config.yaml
metrics:
  receivers:
    prometheus:
      type: prometheus
      config:
        scrape_configs:
          # DCGM Exporter 스크랩 설정
          - job_name: 'dcgm-exporter'
            scrape_interval: 30s
            static_configs:
              - targets: ['localhost:9400']
                labels:
                  instance: '$(hostname)'
                  service: 'gpu-metrics'
          
          # Node Exporter 스크랩 설정
          - job_name: 'node-exporter'
            scrape_interval: 30s
            static_configs:
              - targets: ['localhost:9100']
                labels:
                  instance: '$(hostname)'
                  service: 'node-metrics'
  
  service:
    pipelines:
      prometheus:
        receivers: [prometheus]

logging:
  receivers:
    gpu_logs:
      type: files
      include_paths: [/var/log/nvidia-smi.log]
  
  service:
    pipelines:
      gpu_logs:
        receivers: [gpu_logs]
EOG

# 5. NVIDIA-SMI 로그 생성 스크립트 (기존 코드 재사용)
log_message "▶ NVIDIA-SMI 로깅 스크립트 설정 중..."
cat <<EON > nvidia-smi-logger.sh
#!/bin/bash
LOG_FILE="/var/log/nvidia-smi.log"
while true; do
  echo "$(date): NVIDIA GPU Stats" >> $LOG_FILE
  nvidia-smi --query-gpu=timestamp,name,pci.bus_id,driver_version,utilization.gpu,utilization.memory,memory.total,memory.free,memory.used,temperature.gpu,power.draw --format=csv >> $LOG_FILE
  sleep 30
done
EON

# 스크립트 권한 설정 및 서비스로 등록
chmod +x nvidia-smi-logger.sh
cat <<EOS > /etc/systemd/system/nvidia-smi-logger.service
[Unit]
Description=NVIDIA SMI Logger
After=nvidia-persistenced.service

[Service]
Type=simple
ExecStart=/opt/monitoring/nvidia-smi-logger.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOS

# 서비스 활성화 및 시작
systemctl daemon-reload
systemctl enable nvidia-smi-logger.service
systemctl start nvidia-smi-logger.service

# 6. Ops Agent 재시작하여 새 설정 적용
log_message "▶ Ops Agent 재시작 중..."
systemctl restart google-cloud-ops-agent

# 7. Cloud Monitoring 대시보드 URL 안내
PROJECT_ID=$(gcloud config get-value project)
log_message "✅ 모니터링 에이전트 설치 완료"
log_message "   - NVIDIA DCGM Exporter: http://$(hostname -I | awk '{print $1}'):9400/metrics"
log_message "   - Node Exporter: http://$(hostname -I | awk '{print $1}'):9100/metrics"
log_message "   - Cloud Monitoring 대시보드: https://console.cloud.google.com/monitoring/dashboards?project=$PROJECT_ID"

# 8. Discord로 알림 전송
curl -H "Content-Type: application/json" \
     -X POST \
     -d "{\"content\": \"✅ GPU 모니터링이 설정되었습니다. 서버: $(hostname), 프로젝트: $PROJECT_ID\"}" \
     "${WEBHOOK_URL}"

###################################
# 7. 완료 알림 메타데이터 표시
###################################
log_message "✅ [완료] 스타트업 스크립트 실행 종료 - $(hostname)"
curl -X PUT "http://metadata.google.internal/computeMetadata/v1/instance/guest-attributes/startup-script/status" \
  -H "Metadata-Flavor: Google" \
  -d "DONE"

###################################
# 8. GitHub Actions 셀프호스팅 러너 설치
###################################
log_message "▶ GitHub Actions 셀프호스팅 러너 설치 시작"

# 작업 디렉토리 생성
mkdir -p /opt/actions-runner
cd /opt/actions-runner

# 러너 패키지 다운로드
log_message "▶ GitHub Actions 러너 패키지 다운로드 중..."
curl -o actions-runner-linux-x64-2.323.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.323.0/actions-runner-linux-x64-2.323.0.tar.gz

# 해시 검증
log_message "▶ 패키지 해시 검증 중..."
echo "0dbc9bf5a58620fc52cb6cc0448abcca964a8d74b5f39773b7afcad9ab691e19  actions-runner-linux-x64-2.323.0.tar.gz" | shasum -a 256 -c

# 압축 해제
log_message "▶ 러너 패키지 압축 해제 중..."
tar xzf ./actions-runner-linux-x64-2.323.0.tar.gz

# 필요한 패키지 설치
log_message "▶ 필요한 의존성 패키지 설치 중..."
apt-get update
apt-get install -y jq git curl libicu-dev

# Docker 소켓 권한 조정
log_message "▶ Docker 소켓 권한 조정 중..."
chmod 666 /var/run/docker.sock

# Docker 서비스 재시작 시에도 권한 유지되도록 설정
mkdir -p /etc/systemd/system/docker.service.d
cat > /etc/systemd/system/docker.service.d/override.conf << EOF
[Service]
ExecStartPost=/bin/chmod 666 /var/run/docker.sock
EOF
systemctl daemon-reload
systemctl restart docker

# 러너 구성 - 유저 생성 및 권한 설정
log_message "▶ 러너 실행을 위한 사용자 설정 중..."
useradd -m github-runner || true

# GitHub Actions 러너 사용자에게 Docker 권한 부여
log_message "▶ GitHub Actions 러너 사용자에게 Docker 권한 부여 중..."
usermod -aG docker github-runner

# 디렉토리 권한 설정
chown -R github-runner:github-runner /opt/actions-runner

# GitHub Token을 임시 파일에 저장
echo "${GITHUB_TOKEN}" > /tmp/github_token.txt
chmod 600 /tmp/github_token.txt

# GitHub 레포지토리 정보 설정 ($ 형식으로 변수 선언)
log_message "▶ GitHub 레포지토리 정보 설정..."
OWNER="100-hours-a-week"
REPO="8-pumati-ai"

# API를 통해 러너 등록 토큰 요청 ($ 형식 사용)
log_message "▶ GitHub Actions 러너 토큰 요청 중..."
GITHUB_PAT=$(cat /tmp/github_token.txt)
RUNNER_TOKEN=$(curl -s -X POST \
  -H "Authorization: token $GITHUB_PAT" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$OWNER/$REPO/actions/runners/registration-token" \
  | jq -r .token)

# 토큰 확인
if [ -z "$RUNNER_TOKEN" ] || [ "$RUNNER_TOKEN" = "null" ]; then
  log_message "❌ 러너 토큰을 가져오지 못했습니다. GitHub 토큰 권한을 확인하세요."
  curl -H "Content-Type: application/json" \
       -X POST \
       -d "{\"content\": \"❌ GitHub Actions 러너 토큰 발급 실패. 호스트: $(hostname)\"}" \
       "${WEBHOOK_URL}"
  exit 1
fi

log_message "✅ 러너 토큰을 성공적으로 가져왔습니다."

# 러너 구성 ($ 형식 사용)
log_message "▶ GitHub Actions 러너 구성 중..."
cd /opt/actions-runner
sudo -u github-runner ./config.sh --url "https://github.com/$OWNER/$REPO" --token "$RUNNER_TOKEN" --name "gpu-runner-$(hostname)" --labels "gpu,self-hosted" --unattended

# 임시 토큰 파일 삭제
rm -f /tmp/github_token.txt

# 러너를 서비스로 설치
log_message "▶ GitHub Actions 러너를 서비스로 설치 중..."
./svc.sh install github-runner

# 서비스 시작
log_message "▶ GitHub Actions 러너 서비스 시작 중..."
./svc.sh start

# 서비스 상태 확인
log_message "▶ GitHub Actions 러너 서비스 상태 확인..."
./svc.sh status

# Discord로 알림 전송
curl -H "Content-Type: application/json" \
     -X POST \
     -d "{\"content\": \"✅ GitHub Actions 러너가 설치되었습니다. 호스트: $(hostname), 레이블: gpu,self-hosted\"}" \
     "${WEBHOOK_URL}"

log_message "✅ GitHub Actions 셀프호스팅 러너 설치 완료"