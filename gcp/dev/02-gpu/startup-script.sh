#!/bin/bash

LOGFILE="/var/log/startup-script.log"
log_message() {
  local message="$1"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] $message" | tee -a $LOGFILE
  logger -t startup-script "$message"
}

log_message "✅ [시작] 스타트업 스크립트 실행 - 호스트명: $(hostname)"

# 보안 값 로드 - 테라폼에서 직접 전달받은 변수 사용
# TUNNEL_UUID와 WEBHOOK_URL은 providers.tf에서 전달

##########################
# 1. NVIDIA 드라이버 설치
##########################
log_message "▶ NVIDIA 드라이버 및 CUDA는 이미 딥러닝 VM 이미지에 설치되어 있음"
# 설치 확인
nvidia-smi
log_message "✅ NVIDIA 드라이버 확인 완료"

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
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
dpkg -i cloudflared-linux-amd64.deb

log_message "▶ cloudflared 디렉토리 생성 중"
mkdir -p /etc/cloudflared /root/.cloudflared /var/log/cloudflared

log_message "▶ cloudflared 인증 파일 GCS에서 다운로드 중"
gsutil cp gs://ktb8team-static-storage/cloudflare/${TUNNEL_UUID}.json /etc/cloudflared/llm-tunnel.json
gsutil cp gs://ktb8team-static-storage/cloudflare/cert.pem /root/.cloudflared/cert.pem

log_message "▶ config.yml 설정 파일 생성"
cat <<EOF > /etc/cloudflared/config.yml
tunnel: ${TUNNEL_UUID}
credentials-file: /etc/cloudflared/llm-tunnel.json

ingress:
  - hostname: ai.mydairy.my
    service: http://localhost:8000
  - service: http_status:404
EOF

log_message "▶ cloudflared systemd 서비스 파일 생성"
cat <<EOF > /etc/systemd/system/cloudflared.service
[Unit]
Description=Cloudflare Tunnel
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/bin/cloudflared tunnel --config /etc/cloudflared/config.yml run
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
log_message "✅ cloudflared 터널 서비스 시작 완료"

##################################
# 4. Docker 설정 (이미 설치됨)
##################################
log_message "▶ Docker 및 NVIDIA Container Toolkit은 이미 설치되어 있음"
# 설정 확인
docker info | grep -i nvidia
log_message "✅ Docker NVIDIA 설정 확인 완료"

#############################
# 5. Docker 이미지 실행
#############################
log_message "▶ 애플리케이션 디렉토리 생성 중"
mkdir -p /opt/ai-app
cd /opt/ai-app

log_message "▶ GCS에서 이미지 tar 파일 다운로드 중"
gsutil cp gs://ktb8team-static-storage/ai/ai-test.tar /opt/ai-app/
log_message "✅ 다운로드 완료: ai-test.tar"

log_message "▶ Docker 이미지 로드 시도"
docker load < ai-test.tar
IMAGE_NAME=$(docker images --format "{{.Repository}}:{{.Tag}}" | head -n 1)

if [ -n "$IMAGE_NAME" ]; then
  log_message "✅ 이미지 로드 성공: $IMAGE_NAME"
  log_message "▶ 컨테이너 실행 (GPU 할당 포함)"
  docker run -d --gpus all -p 8000:8000 $IMAGE_NAME
  if [ $? -eq 0 ]; then
    log_message "✅ 컨테이너 실행 성공"
  else
    log_message "❌ 컨테이너 실행 실패 - 다른 포트로 재시도"
    docker run -d --gpus all -P $IMAGE_NAME
  fi
else
    log_message "❌ 이미지 로드 실패"
  # Discord로 알림 전송
  curl -H "Content-Type: application/json" \
       -X POST \
       -d '{"content": "🚨 이미지 로드 실패: Docker 이미지를 GCS에서 로드하지 못했습니다. 서버 $(hostname)를 확인해주세요."}' \
       "${WEBHOOK_URL}"
fi

###################################
# 6. 모니터링 에이전트 설치
###################################
log_message "▶ 모니터링 에이전트 설치 시작"

# 작업 디렉토리 생성
mkdir -p /opt/monitoring
cd /opt/monitoring

# NVIDIA Container Toolkit 확인
if ! docker info | grep -i nvidia > /dev/null; then
  log_message "▶ NVIDIA Container Toolkit 설치 중..."
  distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
  curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
  curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
  apt-get update
  apt-get install -y nvidia-container-toolkit
  systemctl restart docker
  log_message "✅ NVIDIA Container Toolkit 설치 완료"
fi

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

# 3. Promtail 설정 (로그 수집 에이전트)
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
          host: ${HOSTNAME}
          __path__: /var/log/*log

  # GPU 관련 로그 수집
  - job_name: gpu_logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: gpu_logs
          host: ${HOSTNAME}
          __path__: /var/log/nvidia-smi.log

  # Docker 로그 수집
  - job_name: docker
    static_configs:
      - targets:
          - localhost
        labels:
          job: docker
          host: ${HOSTNAME}
          __path__: /var/lib/docker/containers/*/*.log
EOL

# 4. Promtail 실행 (외부 Loki 서버 설정 후 주석 해제 필요)
# log_message "▶ Promtail 실행 중..."
# docker run -d --restart=unless-stopped \
#   --name promtail \
#   -v "/var/log:/var/log" \
#   -v "$(pwd)/promtail-config.yml:/etc/promtail/config.yml" \
#   grafana/promtail:latest \
#   -config.file=/etc/promtail/config.yml

# 5. NVIDIA-SMI 로그 생성 스크립트
log_message "▶ NVIDIA-SMI 로깅 스크립트 설정 중..."
cat <<EOG > nvidia-smi-logger.sh
#!/bin/bash
LOG_FILE="/var/log/nvidia-smi.log"
while true; do
  echo "$(date): NVIDIA GPU Stats" >> $LOG_FILE
  nvidia-smi --query-gpu=timestamp,name,pci.bus_id,driver_version,utilization.gpu,utilization.memory,memory.total,memory.free,memory.used,temperature.gpu,power.draw --format=csv >> $LOG_FILE
  sleep 30
done
EOG

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

systemctl daemon-reload
systemctl enable nvidia-smi-logger.service
systemctl start nvidia-smi-logger.service

log_message "✅ 모니터링 에이전트 설치 완료"
log_message "   - NVIDIA DCGM Exporter: http://$(hostname -I | awk '{print $1}'):9400/metrics"
log_message "   - Node Exporter: http://$(hostname -I | awk '{print $1}'):9100/metrics"
log_message "   - Promtail: 외부 Loki 서버 URL 지정 후 설정 필요"

###################################
# 7. 완료 알림 메타데이터 표시
###################################
log_message "✅ [완료] 스타트업 스크립트 실행 종료 - $(hostname)"
curl -X PUT "http://metadata.google.internal/computeMetadata/v1/instance/guest-attributes/startup-script/status" \
  -H "Metadata-Flavor: Google" \
  -d "DONE"
