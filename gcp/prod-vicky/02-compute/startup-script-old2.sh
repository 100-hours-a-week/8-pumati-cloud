#!/bin/bash

LOGFILE="/var/log/startup-script.log"
log_message() {
  local message="$1"
  local timestamp=$(TZ='Asia/Seoul' date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] $message" | tee -a $LOGFILE
  logger -t startup-script "$message"
}

log_message "✅ [시작] 스타트업 스크립트 실행 - 호스트명: $(hostname)"

###################################
# 1. 영구 디스크 연결 및 마운트 (우선순위 상향)
###################################
log_message "▶ 영구 디스크 연결 및 마운트 시작"

# 메타데이터 서버에서 인스턴스 정보 가져오기
ZONE=${DISK_ZONE}
PROJECT_ID=${PROJECT_ID}
INSTANCE_NAME=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google")
DISK_NAME=${DISK_NAME}


# Terraform에서 전달받은 디스크 정보 사용
log_message "▶ 디스크 정보: 이름=${DISK_NAME}, 영역=$ZONE"

# 기본 구성 설정
gcloud config set project $PROJECT_ID
gcloud config set compute/zone $ZONE

# 현재 인스턴스에 연결된 디스크 목록에서 DISK_NAME 있는지 확인
if ! gcloud compute instances describe "$INSTANCE_NAME" \
  --zone "$ZONE" \
  --format="get(disks.deviceName)" | grep -q "$DISK_NAME"; then
  log_message "▶ 디스크가 연결되어 있지 않음 → attach 시도"
  gcloud compute instances attach-disk "$INSTANCE_NAME" \
    --disk="$DISK_NAME" \
    --device-name="$DISK_NAME" \
    --zone="$ZONE"
    
  log_message "✅ 영구 디스크 연결 완료"
  
  # 디스크 인식 대기
  log_message "▶ 디스크 인식을 위해 10초 대기 중..."
  sleep 10
else
  log_message "✅ 영구 디스크가 이미 연결되어 있습니다"
fi

# 모든 디스크 목록 로깅 (디버깅용)
log_message "▶ 시스템에서 인식된 모든 디스크 목록:"
lsblk >> $LOGFILE

# 영구 디스크 마운트 지점 설정
MOUNT_PATH="/mnt/disks/pd"
DOCKER_DATA_ROOT_ON_PD="$MOUNT_PATH/docker" # PD 내 Docker 데이터 경로 정의

mkdir -p $MOUNT_PATH

# 디스크 장치 찾기 (GCP는 종종 nvme0n2 또는 sdb를 두 번째 디스크로 사용)
DISK_DEVICE=""
if [ -b "/dev/disk/by-id/google-${DISK_NAME}" ]; then
  DISK_DEVICE="/dev/disk/by-id/google-${DISK_NAME}"
  log_message "✅ 디스크 장치 경로: by-id (google-${DISK_NAME})"
elif lsblk | grep -q nvme0n2; then
  DISK_DEVICE="/dev/nvme0n2"
  log_message "✅ 디스크 장치 경로: nvme0n2"
elif lsblk | grep -q sdb; then
  DISK_DEVICE="/dev/sdb"
  log_message "✅ 디스크 장치 경로: sdb"
else
  log_message "⚠️ 디스크 장치를 찾을 수 없습니다. 장치 목록:"
  ls -la /dev/disk/by-id/ >> $LOGFILE
  # exit 1 제거 - 디스크 없어도 계속 진행
fi

# 디스크 장치가 발견된 경우에만 포맷 및 마운트 진행
if [ -n "$DISK_DEVICE" ]; then
  # 파티션 존재 여부 확인 및 포맷
  if ! blkid $DISK_DEVICE; then
    log_message "▶ 파티션이 없어 포맷 진행"
    mkfs.ext4 -m 0 -F -E lazy_itable_init=0,lazy_journal_init=0,discard $DISK_DEVICE
  fi

  # fstab에 마운트 설정 추가
  UUID=$(blkid -s UUID -o value $DISK_DEVICE)
  if ! grep -q $UUID /etc/fstab; then
    log_message "▶ fstab에 마운트 설정 추가"
    echo "UUID=$UUID $MOUNT_PATH ext4 discard,defaults,nofail 0 2" >> /etc/fstab
  fi

  # 마운트
  mount $MOUNT_PATH || mount -a

  # 마운트 확인
  if mount | grep -q "$MOUNT_PATH"; then
    log_message "✅ 영구 디스크 마운트 완료: $MOUNT_PATH"
    df -h $MOUNT_PATH >> $LOGFILE

    #############################################
    # 1-1. Docker 데이터 경로 PD로 설정 (추가됨)
    #############################################
    log_message "▶ Docker 데이터 경로를 영구 디스크($DOCKER_DATA_ROOT_ON_PD)로 설정 시도"

    # 1. PD 내 Docker 데이터 디렉토리 생성
    if mkdir -p "$DOCKER_DATA_ROOT_ON_PD"; then
      log_message "✅ Docker 데이터 디렉토리 생성 완료: $DOCKER_DATA_ROOT_ON_PD"
    else
      log_message "❌ Docker 데이터 디렉토리 생성 실패: $DOCKER_DATA_ROOT_ON_PD. Docker 경로 변경 건너뜀."
      # 실패 시 기존 경로 사용하도록 여기서 더 이상 진행하지 않을 수 있음 (선택)
      # 또는 오류 로깅 후 계속 진행하여 Docker 기본 경로를 사용하게 둘 수 있음
    fi

    # 2. Docker 데몬 설정 파일 생성 (/etc/docker/daemon.json)
    log_message "▶ Docker 데몬 설정 파일(/etc/docker/daemon.json) 생성 중..."
    # 기존 설정이 있을 수 있으므로 jq로 병합하는 것이 안전하나,
    # 스타트업 스크립트에서는 덮어쓰는 것이 간단할 수 있음.
    # 여기서는 간단하게 cat으로 생성 (기존 파일이 있다면 덮어써짐)
    cat <<EOF > /etc/docker/daemon.json
{
  "data-root": "$DOCKER_DATA_ROOT_ON_PD"
}
EOF

    if [ $? -eq 0 ]; then
      log_message "✅ /etc/docker/daemon.json 파일 생성/수정 완료."
      
      # 3. Docker 서비스 재시작 (변경된 설정 적용)
      # Docker 서비스가 이미 실행 중일 수 있으므로 restart 사용
      log_message "▶ Docker 서비스 재시작하여 새 데이터 경로 적용 중..."
      if systemctl restart docker; then
        log_message "✅ Docker 서비스 재시작 성공. 데이터 경로는 이제 $DOCKER_DATA_ROOT_ON_PD 입니다."
      else
        log_message "❌ Docker 서비스 재시작 실패. Docker 기본 경로가 사용될 수 있습니다."
        # 재시작 실패 시 원인 파악 필요 (journalctl -u docker)
      fi
    else
       log_message "❌ /etc/docker/daemon.json 파일 생성 실패. Docker 경로 변경 실패."
    fi
    #############################################
    # Docker 설정 끝
    #############################################

  else
    log_message "❌ 디스크 마운트 실패"
    # 마운트 실패 시 PD 사용 불가, Docker 경로는 기본값(/var/lib/docker) 유지됨
  fi
else
  log_message "❌ 디스크 장치를 찾을 수 없어 마운트 건너뜀"
  # 디스크 없음, Docker 경로는 기본값(/var/lib/docker) 유지됨
fi

# 시스템 패키지 업데이트 (원래 스크립트에서 이 부분이 앞에 있었음)
log_message "▶ 시스템 패키지 업데이트 중..."
if apt-get update && apt-get upgrade -y; then
  log_message "✅ 시스템 패키지 업데이트 완료"
else
  log_message "⚠️ 시스템 패키지 업데이트 중 일부 오류 발생, 계속 진행합니다"
fi

##########################
# 2. NVIDIA 드라이버 설치
##########################
log_message "▶ NVIDIA 드라이버 확인 및 필요시 설치 시작"

# 먼저 드라이버가 이미 설치되어 있는지 확인
if nvidia-smi &> /dev/null; then
  log_message "✅ NVIDIA 드라이버가 이미 설치되어 있고 정상 작동 중입니다"
else
  log_message "⚠️ NVIDIA 드라이버가 설치되지 않았거나 작동하지 않습니다"
  
  # 드라이버 설치 스크립트가 있는지 확인
  if [ -f /opt/deeplearning/install-driver.sh ]; then
    log_message "▶ NVIDIA 드라이버 자동 설치 시작..."
    
    # 드라이버 자동 설치 실행 (--silent 옵션으로 프롬프트 없이 설치)
    /opt/deeplearning/install-driver.sh --silent
    
    # 설치 후 다시 확인
    if nvidia-smi &> /dev/null; then
      log_message "✅ NVIDIA 드라이버 설치 및 확인 완료"
    else
      log_message "❌ NVIDIA 드라이버 설치 시도했으나 여전히 작동하지 않습니다"
      # Discord로 알림 전송
      curl -H "Content-Type: application/json" \
           -X POST \
           -d '{"content": "🚨 NVIDIA 드라이버 문제 발생: 자동 설치 시도했으나 GPU를 사용할 수 없습니다."}' \
           "${WEBHOOK_URL}"
    fi
  else
    log_message "❌ NVIDIA 드라이버 설치 스크립트를 찾을 수 없습니다: /opt/deeplearning/install-driver.sh"
    # Discord로 알림 전송
    curl -H "Content-Type: application/json" \
         -X POST \
         -d '{"content": "🚨 NVIDIA 드라이버 문제 발생: 설치 스크립트를 찾을 수 없어 GPU를 사용할 수 없습니다."}' \
         "${WEBHOOK_URL}"
  fi
fi

# 8080 포트를 점유하는 주피터 끄기. ( 딥러닝 이미지에 있는거임)
log_message "▶ Jupyter 서비스 비활성화 중..."
systemctl disable jupyter || true
systemctl stop jupyter || true
systemctl disable jupyterhub || true
systemctl stop jupyterhub || true


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
  - hostname: dev.mydairy.my
    service: http://localhost:8080
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
Restart=on-failure
RestartSec=5
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
# 4. Docker 설정
##################################
# Docker 네트워크 설정 최적화 (bridge-nf-call 경고 해결)
log_message "▶ Docker 네트워크 bridge-nf-call 설정 활성화 중..."
modprobe br_netfilter
echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables
echo 1 > /proc/sys/net/bridge/bridge-nf-call-ip6tables
# 부팅 후에도 유지되도록 설정
cat > /etc/sysctl.d/90-docker-bridge.conf << EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sysctl -p /etc/sysctl.d/90-docker-bridge.conf
log_message "✅ Docker 네트워크 설정 완료"

###################################
# 6. 모니터링 에이전트 설치
###################################
log_message "▶ 모니터링 에이전트 설치 시작"

# 작업 디렉토리 생성
mkdir -p /opt/monitoring
cd /opt/monitoring

# 1. NVIDIA DCGM Exporter 설치 - GPU 메트릭 수집
log_message "▶ NVIDIA DCGM Exporter 실행 시도 중..."
# 이전 컨테이너가 남아있을 수 있으므로 실행 전 삭제
docker rm -f dcgm-exporter > /dev/null 2>&1 || true

# ───────────────────────────────────────────────────────────
# 수정된 버전: --privileged 추가, KUBERNETES=0 설정
# ───────────────────────────────────────────────────────────
if docker run -d --restart=unless-stopped \
   --name dcgm-exporter \
   --gpus all \
   --privileged \
   -p 9400:9400 \
   -e DCGM_EXPORTER_KUBERNETES=0 \
   nvcr.io/nvidia/k8s/dcgm-exporter:4.2.3-4.1.1-ubuntu22.04; then
   log_message "✅ NVIDIA DCGM Exporter 실행 성공 (nvcr.io/nvidia/k8s/dcgm-exporter:4.2.3-4.1.1-ubuntu22.04)"
else
   log_message "⚠️ 첫 번째 DCGM Exporter 버전 실행 실패, Docker Hub latest로 재시도..."
   docker rm -f dcgm-exporter > /dev/null 2>&1 || true # 재시도 전에도 삭제 시도

   # Docker Hub latest 태그로 재시도 시에도 동일 옵션 적용
   if docker run -d --restart=unless-stopped \
     --name dcgm-exporter \
     --gpus all \
     --privileged \
     -p 9400:9400 \
     -e DCGM_EXPORTER_KUBERNETES=0 \
     nvidia/dcgm-exporter:latest; then
     log_message "✅ NVIDIA DCGM Exporter 실행 성공 (nvidia/dcgm-exporter:latest)"
   else
     log_message "❌ 모든 버전의 DCGM Exporter 실행 실패."
     # 필요시 실패 알림 추가
   fi
fi

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

## 2. Promtail 활성화 방법
1. promtail-config.yml 파일에서 아래 부분을 수정:
   ```yaml
   clients:
     - url: http://YOUR_LOKI_SERVER_IP:3100/loki/api/v1/push
   ```


## 3. Grafana에서 Loki 데이터소스 추가
1. Grafana에 접속 (http://GRAFANA_IP:3000)
2. Configuration > Data Sources > Add data source
3. Loki 선택
4. URL에 http://LOKI_SERVER_IP:3100 입력
5. Save & Test
EOH


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
# 8. GitHub Actions 셀프호스팅 러너 설치
###################################
log_message "▶ GitHub Actions 셀프호스팅 러너 설치 시작"

# --- 추가: 영구 디스크 마운트 확인 ---
# 이 섹션이 실행되기 전에 PD가 /mnt/disks/pd 에 마운트되었는지 확인하는 것이 좋습니다.
# (앞선 섹션 1에서 마운트 실패 시 이 부분을 건너뛰거나 로그를 남길 수 있습니다.)
if ! mount | grep -q "/mnt/disks/pd"; then
  log_message "❌ 영구 디스크(/mnt/disks/pd)가 마운트되지 않아 GitHub Actions 러너 설치를 건너<0xEB><0x9A><0x81>니다."
  # 필요시 여기서 스크립트 실행을 중단하거나 다음 단계로 넘어갈 수 있습니다.
  # exit 1 # 또는 다른 처리
else
  log_message "✅ 영구 디스크 확인됨. 러너를 /mnt/disks/pd/actions-runner 에 설치합니다."

  # 작업 디렉토리를 영구 디스크 내에 생성
  RUNNER_BASE_DIR="/mnt/disks/pd/actions-runner" # PD 내 경로 지정
  mkdir -p "$RUNNER_BASE_DIR"
  cd "$RUNNER_BASE_DIR" # 작업 디렉토리를 PD 내로 변경

  # 러너 패키지 다운로드 (동일)
  log_message "▶ GitHub Actions 러너 패키지 다운로드 중..."
  curl -o actions-runner-linux-x64-2.323.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.323.0/actions-runner-linux-x64-2.323.0.tar.gz

  # 해시 검증 (동일)
  log_message "▶ 패키지 해시 검증 중..."
  echo "0dbc9bf5a58620fc52cb6cc0448abcca964a8d74b5f39773b7afcad9ab691e19  actions-runner-linux-x64-2.323.0.tar.gz" | shasum -a 256 -c

  # 압축 해제 (변경된 작업 디렉토리에서 실행)
  log_message "▶ 러너 패키지 압축 해제 중..."
  tar xzf ./actions-runner-linux-x64-2.323.0.tar.gz
  rm ./actions-runner-linux-x64-2.323.0.tar.gz # 압축 해제 후 tar 파일 삭제 (선택 사항)

  # 필요한 패키지 설치 (동일)
  log_message "▶ 필요한 의존성 패키지 설치 중..."
  apt-get update
  apt-get install -y jq git curl libicu-dev

  # Docker 소켓 권한 조정 (동일, 러너가 Docker 사용 시 필요)
  log_message "▶ Docker 소켓 권한 조정 중..."
  chmod 666 /var/run/docker.sock
  # Docker 재시작 시 권한 유지 설정 (동일)
  mkdir -p /etc/systemd/system/docker.service.d
  cat > /etc/systemd/system/docker.service.d/override.conf << EOF
[Service]
ExecStartPost=/bin/chmod 666 /var/run/docker.sock
EOF
  systemctl daemon-reload
  systemctl restart docker

  # 러너 구성 - 유저 생성 및 권한 설정 (동일)
  log_message "▶ 러너 실행을 위한 사용자 설정 중..."
  useradd -m github-runner || true
  usermod -aG docker github-runner # 러너가 Docker 사용 시 권한 부여

  # 디렉토리 권한 설정 (변경된 경로에 적용)
  chown -R github-runner:github-runner "$RUNNER_BASE_DIR"

  # GitHub Token 임시 파일 저장 (동일)
  echo "${GITHUB_TOKEN}" > /tmp/github_token.txt
  chmod 600 /tmp/github_token.txt

  # GitHub 레포 정보 및 러너 토큰 요청 (동일)
  log_message "▶ GitHub 레포지토리 정보 설정..."
  OWNER="100-hours-a-week"
  REPO="8-pumati-ai"
  log_message "▶ GitHub Actions 러너 토큰 요청 중..."
  GITHUB_PAT=$(cat /tmp/github_token.txt)
  RUNNER_TOKEN=$(curl -s -X POST \
    -H "Authorization: token $GITHUB_PAT" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$OWNER/$REPO/actions/runners/registration-token" \
    | jq -r .token)

  # 토큰 확인 (동일)
  if [ -z "$RUNNER_TOKEN" ] || [ "$RUNNER_TOKEN" = "null" ]; then
    log_message "❌ 러너 토큰을 가져오지 못했습니다. GitHub 토큰 권한을 확인하세요."
    # ... (오류 처리 및 알림) ...
    exit 1
  fi
  log_message "✅ 러너 토큰을 성공적으로 가져왔습니다."

  # 러너 구성 (변경된 작업 디렉토리에서 실행, github-runner 사용자로 실행)
  log_message "▶ GitHub Actions 러너 구성 중..."
  # cd "$RUNNER_BASE_DIR" # 이미 해당 디렉토리에 있음
  sudo -u github-runner ./config.sh --url "https://github.com/$OWNER/$REPO" --token "$RUNNER_TOKEN" --name "gpu-runner-$(hostname)-pd" --labels "gpu,self-hosted,pd-cache" --work "$RUNNER_BASE_DIR/_work" --unattended # 작업 디렉토리 명시 (--work)

  # 임시 토큰 파일 삭제 (동일)
  rm -f /tmp/github_token.txt

  # 러너를 서비스로 설치 (변경된 작업 디렉토리에서 실행)
  log_message "▶ GitHub Actions 러너를 서비스로 설치 중..."
  ./svc.sh install github-runner

  # 서비스 시작 (동일)
  log_message "▶ GitHub Actions 러너 서비스 시작 중..."
  ./svc.sh start

  # 서비스 상태 확인 (동일)
  log_message "▶ GitHub Actions 러너 서비스 상태 확인..."
  ./svc.sh status

  # Discord 알림 전송 (동일)
  curl -H "Content-Type: application/json" \
      -X POST \
      -d "{\"content\": \"✅ GitHub Actions 러너가 설치되었습니다. 호스트: $(hostname), 레이블: gpu,self-hosted,pd-cache, 설치 경로: $RUNNER_BASE_DIR\"}" \
      "${WEBHOOK_URL}"

  log_message "✅ GitHub Actions 셀프호스팅 러너 설치 완료 (PD 경로: $RUNNER_BASE_DIR)"

fi # 영구 디스크 마운트 확인 if 블록 종료

###################################
# 9. 도커 이미지 가져오기 및 실행
###################################
log_message "▶ Artifact Registry에서 AI 서비스 이미지 가져오기 시작"

# 작업 디렉토리 생성
mkdir -p /etc/sa
cd /etc/sa

# SA_KEY_CONTENT_BASE64 환경변수에서 서비스 계정 키 파일 생성
log_message "▶ 서비스 계정 인증 설정 중 (Base64 디코딩 방식)..."
mkdir -p /etc/sa # 디렉토리가 없으면 생성

# SA_KEY_CONTENT_BASE64 환경변수가 비어있는지 먼저 확인
if [ -z "${SA_KEY_CONTENT_BASE64}" ]; then
  log_message "❌ SA_KEY_CONTENT_BASE64 환경변수가 비어 있습니다. 서비스 계정 키를 전달할 수 없습니다."
  curl -H "Content-Type: application/json" \
       -X POST \
       -d "{\"content\": \"🚨 SA_KEY_CONTENT_BASE64 환경변수 비어있음: 호스트 $(hostname)에서 서비스 계정 키 파일 생성 불가.\"}" \
       "${WEBHOOK_URL}"
  exit 1
fi

# Base64 디코딩하여 파일로 저장
# 디코딩 실패 시 오류를 명확히 알 수 있도록 set -e 와 유사하게 처리
if ! echo "${SA_KEY_CONTENT_BASE64}" | base64 --decode > /etc/sa/ktb8team-reader.json; then
  log_message "❌ Base64 디코딩 실패 또는 파일 쓰기 실패."
  # 디코딩 시도한 내용의 일부를 로그로 남겨 디버깅 (앞 100자)
  log_message "   SA_KEY_CONTENT_BASE64 변수 내용 (일부): $(echo "${SA_KEY_CONTENT_BASE64}" | head -c 100)"
  curl -H "Content-Type: application/json" \
       -X POST \
       -d "{\"content\": \"🚨 서비스 계정 키 Base64 디코딩 실패: 호스트 $(hostname)\"}" \
       "${WEBHOOK_URL}"
  exit 1
fi

chmod 600 /etc/sa/ktb8team-reader.json

# 파일이 정상적으로 생성되었고 내용이 있는지 확인
if [ ! -s /etc/sa/ktb8team-reader.json ]; then
  log_message "❌ /etc/sa/ktb8team-reader.json 파일이 디코딩 후에도 비어 있거나 생성되지 않았습니다."
  curl -H "Content-Type: application/json" \
       -X POST \
       -d "{\"content\": \"🚨 서비스 계정 키 파일 생성 실패 (디코딩 후 비어있음): 호스트 $(hostname)\"}" \
       "${WEBHOOK_URL}"
  exit 1
else
  log_message "✅ /etc/sa/ktb8team-reader.json 파일 생성 및 Base64 디코딩 완료."
fi

# 키 파일 경로 설정
KEY_FILE="/etc/sa/ktb8team-reader.json"

# 1. 서비스 계정 인증
log_message "▶ GCP 서비스 계정 활성화 중..."
if gcloud auth activate-service-account --key-file="$KEY_FILE"; then
  log_message "✅ 서비스 계정 인증 성공"
else
  log_message "❌ 서비스 계정 인증 실패"
  curl -H "Content-Type: application/json" \
       -X POST \
       -d "{\"content\": \"🚨 서비스 계정 인증 실패: 호스트 $(hostname)에서 Artifact Registry에 접근할 수 없습니다.\"}" \
       "${WEBHOOK_URL}"
  exit 1
fi

# 2. Artifact Registry용 Docker 인증
log_message "▶ Docker에 Artifact Registry 인증 설정 중..."
if gcloud auth configure-docker asia-east1-docker.pkg.dev --quiet; then
  log_message "✅ Docker Artifact Registry 인증 설정 완료"
else
  log_message "❌ Docker Artifact Registry 인증 설정 실패"
  curl -H "Content-Type: application/json" \
       -X POST \
       -d "{\"content\": \"🚨 Docker Artifact Registry 인증 설정 실패: 호스트 $(hostname)\"}" \
       "${WEBHOOK_URL}"
  exit 1
fi

# 3. 이미지 pull & 컨테이너 실행
log_message "▶ AI 서비스 이미지 다운로드 중..."
IMAGE="asia-east1-docker.pkg.dev/ktb8team-458916/ktb8team/dev/ai"

if docker pull "$IMAGE:latest"; then
  log_message "✅ 이미지 다운로드 성공: $IMAGE:latest"
else
  log_message "❌ 이미지 다운로드 실패"
  curl -H "Content-Type: application/json" \
       -X POST \
       -d "{\"content\": \"🚨 AI 이미지 다운로드 실패: 호스트 $(hostname)에서 $IMAGE:latest를 가져올 수 없습니다.\"}" \
       "${WEBHOOK_URL}"
  exit 1
fi

# 기존 컨테이너 중지 및 삭제
log_message "▶ 기존 AI 서비스 컨테이너 정리 중..."
docker stop ai >/dev/null 2>&1 || true
docker rm ai >/dev/null 2>&1 || true

# 새 컨테이너 실행
log_message "▶ AI 서비스 컨테이너 시작 중..."
if docker run --gpus all -d --restart unless-stopped --name ai -p 8080:8080 "$IMAGE:latest"; then
  log_message "✅ AI 서비스 컨테이너 실행 성공"
  
  # AI 서비스가 충분히 시작할 시간 제공
  log_message "▶ AI 서비스 초기화 대기 중 (60초)..."
  sleep 60  # 서비스 초기화에 충분한 시간 제공
  
  # 단순 반복문으로 변경
  HEALTH_SUCCESS=false
  

  # /healthz 엔드포인트 확인 (기존 /api에서 변경)
  if [ "$HEALTH_SUCCESS" = false ]; then
    for i in $(seq 1 10); do
      if curl -sf "http://localhost:8080/healthz"; then
        log_message "✅ AI 서비스 응답 확인 (엔드포인트: /healthz)"
        HEALTH_SUCCESS=true
        break
      fi
      log_message "⏳ 헬스체크 재시도 $i/10 (엔드포인트: /healthz)..."
      sleep 5
    done
  fi

  #   # /health 엔드포인트 확인
  # for i in $(seq 1 10); do
  #   if curl -sf "http://localhost:8080/health"; then
  #     log_message "✅ AI 서비스 응답 확인 (엔드포인트: /health)"
  #     HEALTH_SUCCESS=true
  #     break
  #   fi
  #   log_message "⏳ 헬스체크 재시도 $i/10 (엔드포인트: /health)..."
  #   sleep 5
  # done

  # # 두 번째 실패시 루트 경로 확인
  # if [ "$HEALTH_SUCCESS" = false ]; then
  #   for i in $(seq 1 10); do
  #     if curl -sf "http://localhost:8080/status"; then
  #       log_message "✅ AI 서비스 응답 확인 (엔드포인트: /status)"
  #       HEALTH_SUCCESS=true
  #       break
  #     fi
  #     log_message "⏳ 헬스체크 재시도 $i/10 (엔드포인트: /status)..."
  #     sleep 5
  #   done
  # fi
  
  if [ "$HEALTH_SUCCESS" = false ]; then
    log_message "⚠️ 헬스체크 응답 없음: 서비스가 다른 방식으로 실행 중일 수 있음"
    # 실패해도 치명적인 오류로 처리하지 않음
  fi
  
  # 성공 알림 전송
  curl -H "Content-Type: application/json" \
       -X POST \
       -d "{\"content\": \"✅ AI 서비스가 시작되었습니다. 호스트: $(hostname), 포트: 8080\"}" \
       "${WEBHOOK_URL}"
else
  log_message "❌ AI 서비스 컨테이너 실행 실패"
  docker logs ai
  
  # 실패 시 로그 수집 (최대 50줄)
  CONTAINER_LOGS="$(docker logs ai 2>&1 | tail -n 50 || echo '로그를 가져올 수 없습니다')"
  
  # 상세 에러 메시지를 Discord로 전송
  curl -H "Content-Type: application/json" -X POST -d '{
    "username": "🤖 PUMATI 인공지능 배포 봇",
    "avatar_url": "https://avatars.githubusercontent.com/u/583231",
    "content": "🚨 **컨테이너 시작 실패** - '"$(hostname)"'",
    "embeds": [{
      "title": "❌ 컨테이너 시작 실패",
      "color": 16711680,
      "description": "AI 서비스 컨테이너 시작에 실패했습니다. 로그를 확인하세요.",
      "fields": [
        {
          "name": "🖥️ 호스트 정보",
          "value": "```\n'"$(hostname)"'\n```",
          "inline": false
        },
        {
          "name": "⏰ 실패 시간",
          "value": "'"$(TZ='Asia/Seoul' date '+%Y-%m-%d %H:%M:%S')"'",
          "inline": false
        },
        {
          "name": "📄 컨테이너 로그",
          "value": "```\n'$(echo "$CONTAINER_LOGS" | head -c 1000)'\n```",
          "inline": false
        }
      ],
      "footer": {
        "text": "🚫 컨테이너 시작 실패 - 수동 조치가 필요합니다"
      }
    }]
  }' "$WEBHOOK_URL_AI"
fi

log_message "✅ AI 서비스 설정 완료"

###################################
# 10. 주기적 이미지 감지 및 재시작 설정
###################################
log_message "▶ 도커 이미지 자동 업데이트 감시 서비스 설정 중..."

# watcher.sh 파일에 디스크 용량 체크 및 이미지 정리 로직 추가
cat <<'EOT' > /opt/monitoring/watcher.sh
#!/bin/bash

# 로그 파일 경로 명시적 정의
LOGFILE="/var/log/image-watcher.log"

# 로그 함수 정의 - 한국 시간대 적용
log_message() {
  local message="$1"
  local timestamp=$(TZ='Asia/Seoul' date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] $message" | tee -a "$LOGFILE"
}

# 작동 중인 이미지 ID 저장 함수 (롤백용)
save_working_image() {
  local container_id="$1"
  if [ -n "$container_id" ]; then
    local image_id=$(docker inspect --format='{{.Image}}' "$container_id" 2>/dev/null)
    if [ -n "$image_id" ]; then
      echo "$image_id" > /tmp/last_working_image_id.txt
      log_message "✅ 작동 중인 이미지 ID 저장 완료: $image_id"
    fi
  fi
}

# 환경 설정 - 환경변수는 systemd 서비스에서 전달받음 (한국 시간대 적용)
TIMESTAMP=$(TZ='Asia/Seoul' date '+%Y-%m-%d %H:%M:%S')
echo "[$TIMESTAMP] ▶ AI 서비스 이미지 자동 업데이트 감시 시작" | tee -a "$LOGFILE"

# 인증 설정
gcloud auth activate-service-account --key-file="$KEY_FILE" >> "$LOGFILE" 2>&1
gcloud auth configure-docker asia-east1-docker.pkg.dev --quiet >> "$LOGFILE" 2>&1

# jq와 bc 설치 확인 및 설치
if ! command -v jq &> /dev/null; then
    apt-get update && apt-get install -y jq
fi

if ! command -v bc &> /dev/null; then
    apt-get update && apt-get install -y bc
fi

# 디스크 용량 확인 및 정리 함수 (한국 시간대 적용)
check_disk_space() {
  # 루트 파티션의 가용 공간 확인 (GB 단위)
  local AVAIL_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
  
  echo "[$TIMESTAMP] 디스크 여유 공간: $AVAIL_SPACE GB" >> "$LOGFILE"
  
  # 디스크 여유 공간이 50GB 미만이면 정리 시작
  if [ "$AVAIL_SPACE" -lt 50 ]; then
    echo "[$TIMESTAMP] ⚠️ 디스크 공간 부족 ($AVAIL_SPACE GB). 도커 이미지 정리 시작..." | tee -a "$LOGFILE"
    
    # 사용 중인 컨테이너의 이미지 ID 가져오기 (삭제 제외 대상)
    RUNNING_IMAGES=$(docker ps -q | xargs -r docker inspect -f '{{.Image}}')
    
    # 최신 순으로 이미지 목록 가져오기 (현재 사용 중인 이미지는 제외)
    ALL_IMAGES=$(docker images "$IMAGE" --format "{{.ID}}" | grep -v "$RUNNING_IMAGES")
    
    # 이미지 목록에서 최신 3개를 제외한 나머지 추출
    OLD_IMAGES=$(echo "$ALL_IMAGES" | tail -n +4)
    
    if [ -n "$OLD_IMAGES" ]; then
      echo "[$TIMESTAMP] 🧹 오래된 이미지 정리 중 (최신 3개 유지)..." | tee -a "$LOGFILE"
      echo "$OLD_IMAGES" | xargs -r docker rmi -f >> "$LOGFILE" 2>&1
      echo "[$TIMESTAMP] ✅ 이미지 정리 완료" | tee -a "$LOGFILE"
    else
      echo "[$TIMESTAMP] ℹ️ 정리할 이미지가 없습니다." | tee -a "$LOGFILE"
    fi
    
    # 추가로 모든 중단된 컨테이너와 사용되지 않는 이미지 정리
    echo "[$TIMESTAMP] 🧹 추가 도커 시스템 정리 중..." | tee -a "$LOGFILE"
    docker container prune -f >> "$LOGFILE" 2>&1
    docker image prune -f >> "$LOGFILE" 2>&1
    
    # 디스크 상태 재확인
    AVAIL_SPACE_AFTER=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    echo "[$TIMESTAMP] 정리 후 디스크 여유 공간: $AVAIL_SPACE_AFTER GB ($AVAIL_SPACE GB에서 증가)" | tee -a "$LOGFILE"
  fi
}

# 함수 출력과 로그 분리를 위해 수정된 원격 다이제스트 함수
# 원격 다이제스트 조회 함수 (수정)
get_remote_digest() {
  image_name="$1"
  log_message "🔍 Artifact Registry에서 'latest' 태그 다이제스트 조회 시도: $image_name" >&2

  # 1) gcloud artifacts docker images describe 방식 시도
  log_message "▶ 방법 1: gcloud artifacts docker images describe 시도" >&2
  gcloud_result=$(gcloud artifacts docker images describe "$image_name:latest" --format="get(image_summary.digest)" 2>/dev/null)
  if [ -n "$gcloud_result" ] && [ "$gcloud_result" != "null" ]; then
    log_message "✅ gcloud describe로 다이제스트 획득 성공: $gcloud_result" >&2
    echo "$gcloud_result"
    return 0
  else
    log_message "⚠️ gcloud describe 방식 실패, 다음 방법 시도" >&2
  fi

  # 2) gcloud tags list 방식 시도
  log_message "▶ 방법 2: gcloud artifacts docker tags list 시도" >&2
  tags_json=$(gcloud artifacts docker tags list "$image_name" --format=json 2>/dev/null)
  if [ -n "$tags_json" ]; then
    # jq 결과 디버깅을 위한 임시 변수
    jq_debug=$(echo "$tags_json" | jq -r '.[] | select(.tags|index("latest")) | .digest' 2>/dev/null)
    log_message "jq 처리 결과: '$jq_debug'" >&2
    
    if [ -n "$jq_debug" ] && [ "$jq_debug" != "null" ]; then
      log_message "✅ gcloud tags list로 다이제스트 획득 성공: $jq_debug" >&2
      echo "$jq_debug"
      return 0
    else
      log_message "⚠️ tags list에서 latest 태그를 찾지 못함" >&2
    fi
  else
    log_message "⚠️ tags list 결과 없음" >&2
  fi

  # 3) HTTP API fallback
  log_message "▶ 방법 3: HTTP API 직접 호출 시도" >&2
  TOKEN=$(gcloud auth print-access-token 2>/dev/null)
  if [ -z "$TOKEN" ]; then
    log_message "❌ API 인증 토큰 획득 실패" >&2
    echo ""
    return 1
  fi
  log_message "✅ API 인증 토큰 획득 성공" >&2

  # URL 구성 - 정확히 파싱
  registry=$(echo "$image_name" | cut -d/ -f1)
  project=$(echo "$image_name" | cut -d/ -f2)
  repo_path=$(echo "$image_name" | cut -d/ -f3-)
  url="https://$registry/v2/$project/$repo_path/manifests/latest"
  log_message "▶ API 요청 URL: $url" >&2

  # curl 디버깅 활성화
  log_message "▶ curl 요청 시작..." >&2
  http_response=$(curl -v -sS -H "Authorization: Bearer $TOKEN" \
     -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
     "$url" 2>&1)
  
  # 응답 헤더에서 다이제스트 추출
  digest=$(echo "$http_response" | grep -i "Docker-Content-Digest:" | head -n 1 | awk '{print $2}' | tr -d '\r')
  
  if [ -n "$digest" ]; then
    log_message "✅ API 직접 호출로 다이제스트 획득 성공: $digest" >&2
    echo "$digest"
    return 0
  else
    # 오류 분석을 위해 응답 일부 로깅
    response_sample=$(echo "$http_response" | head -n 20)
    log_message "❌ API 호출 실패. 응답 샘플:" >&2
    log_message "$response_sample" >&2
    echo ""
    return 1
  fi
}

# 로컬 다이제스트 조회 함수 (수정)
get_local_digest() {
  image="$1"
  # 중복 :latest 제거
  image=$(echo "$image" | sed 's/:latest:latest/:latest/g')
  digest=""
  
  # 실행 중인 컨테이너 확인 (정확한 이름 일치)
  log_message "▶ 컨테이너 '$NAME' 상태 확인 중..." >&2
  container_status=$(docker ps -a --filter "name=^$NAME$" --format "{{.Status}}")
  
  if [ -n "$container_status" ]; then
    log_message "✅ 컨테이너 '$NAME' 발견: $container_status" >&2
    # 컨테이너 ID 가져오기
    cid=$(docker ps -q -f "name=^$NAME$")
    
    if [ -n "$cid" ]; then
      log_message "✅ 실행 중인 컨테이너 ID: $cid" >&2
      
      # 이미지 ID 먼저 확인
      image_id=$(docker inspect --format='{{.Image}}' "$cid" 2>/dev/null)
      log_message "✅ 컨테이너 이미지 ID: $image_id" >&2
      
      # RepoDigests 정보 가져오기 (전체 목록)
      repo_digests=$(docker inspect --format='{{json .RepoDigests}}' "$image_id" 2>/dev/null)
      log_message "▶ RepoDigests 정보: $repo_digests" >&2
      
      # 첫 번째 RepoDigest 추출 시도
      first_digest=$(docker inspect --format='{{index .RepoDigests 0}}' "$image_id" 2>/dev/null)
      
      if [ -n "$first_digest" ]; then
        # @ 기준으로 오른쪽 부분(다이제스트)만 추출
        digest=$(echo "$first_digest" | cut -d '@' -f 2)
        log_message "✅ 컨테이너에서 다이제스트 획득 성공: $digest" >&2
      else
        log_message "⚠️ 컨테이너 이미지에 RepoDigests 정보 없음" >&2
      fi
    else
      log_message "⚠️ 컨테이너 '$NAME'이 정지 상태임" >&2
    fi
  else
    log_message "⚠️ 컨테이너 '$NAME'을 찾을 수 없음" >&2
  fi
  
  # 컨테이너에서 다이제스트를 찾지 못한 경우 이미지에서 직접 조회
  if [ -z "$digest" ]; then
    log_message "▶ 이미지 '$image' 직접 검사 시도" >&2
    
    # 이미지가 존재하는지 먼저 확인
    if docker inspect "$image" &>/dev/null; then
      log_message "✅ 이미지 '$image' 발견" >&2
      
      # RepoDigests 직접 조회
      repo_digests=$(docker inspect --format='{{json .RepoDigests}}' "$image" 2>/dev/null)
      log_message "▶ 이미지 RepoDigests: $repo_digests" >&2
      
      # 첫 번째 RepoDigest 추출
      first_digest=$(docker inspect --format='{{index .RepoDigests 0}}' "$image" 2>/dev/null)
      
      if [ -n "$first_digest" ]; then
        # @ 기준으로 오른쪽 부분(다이제스트)만 추출
        digest=$(echo "$first_digest" | cut -d '@' -f 2)
        log_message "✅ 이미지에서 다이제스트 획득 성공: $digest" >&2
      else
        log_message "⚠️ 이미지에 RepoDigests 정보 없음" >&2
      fi
    else
      log_message "❌ 이미지 '$image'를 찾을 수 없음" >&2
    fi
  fi
  
  # 다이제스트 값 반환
  if [ -n "$digest" ]; then
    echo "$digest"
    return 0
  else
    log_message "❌ 다이제스트를 찾을 수 없음" >&2
    echo ""
    return 1
  fi
}

while true; do
  # while 문 시작 표시
  log_message "🔄 이미지 업데이트 루프 시작-------------------------------------------"
  TIMESTAMP=$(TZ='Asia/Seoul' date '+%Y-%m-%d %H:%M:%S')

  # --- 루프 내에서 인증 갱신 ---
  log_message "▶ 루프 내 GCP 인증 갱신 시도..."
  # activate-service-account의 출력을 로그 파일로 리다이렉션
  if gcloud auth activate-service-account --key-file="$KEY_FILE" >> "$LOGFILE" 2>&1; then
    log_message "✅ 서비스 계정 활성화 성공"
  else
    log_message "❌ 서비스 계정 활성화 실패. 키 파일: $KEY_FILE. 다음 주기에 재시도합니다."
    sleep 60 
    continue
  fi

  # configure-docker의 출력을 로그 파일로 리다이렉션 (오류 확인을 위해 --quiet 임시 제거 고려)
  # if gcloud auth configure-docker asia-east1-docker.pkg.dev --quiet >> "$LOGFILE" 2>&1; then
  if gcloud auth configure-docker asia-east1-docker.pkg.dev >> "$LOGFILE" 2>&1; then
    log_message "✅ Docker 인증 설정 성공"
  else
    log_message "❌ Docker 인증 설정 실패. 다음 주기에 재시도합니다."
    sleep 60
    continue
  fi
  # --- 인증 갱신 끝 ---
  
  # 디스크 공간 확인 및 정리 (1시간마다 실행)
  if [ $(($(date +%s) % 3600)) -lt 10 ]; then
    check_disk_space
  fi
  
  # 2. 컨테이너 실행 중인지 확인
  CONTAINER_RUNNING=$(docker ps -q -f name="^$NAME$")
  
  if [ -z "$CONTAINER_RUNNING" ]; then
    # 컨테이너가 실행 중이 아니면 pull 후 시작
    echo "[$TIMESTAMP] 컨테이너가 실행 중이 아님. 이미지 pull 및 시작 중..." | tee -a "$LOGFILE"
    
    # if docker pull "$IMAGE:latest" > /dev/null 2>&1; then
    if docker pull "$IMAGE:latest"; then
      if docker run --gpus all -d --restart unless-stopped --name "$NAME" -p 8080:8080 "$IMAGE:latest"; then
        echo "[$TIMESTAMP] ✅ 컨테이너 시작 성공" | tee -a "$LOGFILE"
        
        # 현재 시간 (KST)
        CURRENT_TIME=$(TZ='Asia/Seoul' date '+%Y년 %m월 %d일 %H:%M:%S')
        
        # 이미지 정보 가져오기
        IMAGE_INFO=$(docker inspect "$IMAGE:latest" 2>/dev/null)
        IMAGE_CREATED=$(echo "$IMAGE_INFO" | jq -r '.[0].Created')
        IMAGE_SIZE=$(echo "$IMAGE_INFO" | jq -r '.[0].Size')
        IMAGE_SIZE_GB=$(echo "scale=2; $IMAGE_SIZE/1024/1024/1024" | bc)
        
        # 깃헙 정보 가져오기 (CI에서 추가한 레이블)
        GIT_AUTHOR=$(docker inspect "$IMAGE:latest" | jq -r '.[0].Config.Labels.git_author // "알 수 없음"')
        GIT_COMMIT=$(docker inspect "$IMAGE:latest" | jq -r '.[0].Config.Labels.git_commit // "알 수 없음"')
        GIT_MESSAGE=$(docker inspect "$IMAGE:latest" | jq -r '.[0].Config.Labels.git_message // "알 수 없음"')
        
        # Discord 웹훅 페이로드 - 배포 성공
        curl -H "Content-Type: application/json" -X POST -d '{
          "username": "🤖 PUMATI 인공지능 배포 봇",
          "avatar_url": "https://avatars.githubusercontent.com/u/583231",
          "content": "🌟 **'"$GIT_AUTHOR"'** 님이 푸시한 AI 서비스가 배포되었습니다! 🚀",
          "embeds": [{
            "title": "✅ AI 서비스 배포 성공! 🎉 🎊",
            "color": 3066993,
            "description": "🔥 **'"$GIT_AUTHOR"'** 님이 푸시한 코드의 Docker 이미지 빌드 및 배포가 성공적으로 완료되었습니다! 🙌",
            "fields": [
              {
                "name": "👨‍💻 푸시한 사람 👑",
                "value": "```fix\n'"$GIT_AUTHOR"'\n```",
                "inline": false
              },
              {
                "name": "📝 커밋 메시지 💬",
                "value": "📌 '"$GIT_MESSAGE"' 📎",
                "inline": false
              },
              {
                "name": "🖥️ 호스트 정보 💻",
                "value": "```fix\n'"$(hostname)"'\n```",
                "inline": false
              },
              {
                "name": "🕒 배포 시간 ⏰",
                "value": "🗓️ '"$CURRENT_TIME"' 🕰️",
                "inline": true
              },
              {
                "name": "🖼️ 이미지 정보 📦",
                "value": "```\n이미지: '"$IMAGE"'\n크기: '"$IMAGE_SIZE_GB"' GB\n커밋: '"$GIT_COMMIT"'\n```",
                "inline": false
              },
              {
                "name": "🌐 서비스 URL 🔗",
                "value": "http://'"$(hostname -I | awk '{print $1}')"':8080",
                "inline": false
              }
            ],
            "thumbnail": {
              "url": "https://robohash.org/'"$GIT_AUTHOR"'?set=set3&size=128x128"
            },
            "footer": {
              "text": "🏆 ktb8team AI 서비스 배포 시스템 - '"$(hostname)"' 🛠️"
            }
          }]
        }' "$WEBHOOK_URL_AI"
      else
        echo "[$TIMESTAMP] ❌ 컨테이너 시작 실패" | tee -a "$LOGFILE"
        
        # 실패 시 로그 수집 (최대 50줄)
        CONTAINER_LOGS="$(docker logs $NAME 2>&1 | tail -n 50 || echo '로그를 가져올 수 없습니다')"
        
        # 상세 에러 메시지를 Discord로 전송
        curl -H "Content-Type: application/json" -X POST -d '{
          "username": "🤖 PUMATI 인공지능 배포 봇",
          "avatar_url": "https://avatars.githubusercontent.com/u/583231",
          "content": "🚨 **컨테이너 시작 실패** - '"$(hostname)"'",
          "embeds": [{
            "title": "❌ 컨테이너 시작 실패",
            "color": 16711680,
            "description": "AI 서비스 컨테이너 시작에 실패했습니다. 로그를 확인하세요.",
            "fields": [
              {
                "name": "🖥️ 호스트 정보",
                "value": "```\n'"$(hostname)"'\n```",
                "inline": false
              },
              {
                "name": "⏰ 실패 시간",
                "value": "'"$(TZ='Asia/Seoul' date '+%Y-%m-%d %H:%M:%S')"'",
                "inline": false
              },
              {
                "name": "📄 컨테이너 로그",
                "value": "```\n'$(echo "$CONTAINER_LOGS" | head -c 1000)'\n```",
                "inline": false
              }
            ],
            "footer": {
              "text": "🚫 컨테이너 시작 실패 - 수동 조치가 필요합니다"
            }
          }]
        }' "$WEBHOOK_URL_AI"
      fi
    else
      echo "[$TIMESTAMP] ❌ 이미지 pull 실패" | tee -a "$LOGFILE"
      
      # 이미지 pull 실패 알림에 다이제스트 정보 추가
      curl -H "Content-Type: application/json" -X POST -d '{
        "username": "🤖 PUMATI 인공지능 배포 봇",
        "avatar_url": "https://avatars.githubusercontent.com/u/583231",
        "content": "🚨 **새 이미지 Pull 실패** - '"$(hostname)"'",
        "embeds": [{
          "title": "❌ 새 Docker 이미지 다운로드 실패",
          "color": 16711680,
          "description": "새 도커 이미지를 가져오는 데 실패했습니다.",
          "fields": [
            {
              "name": "🖥️ 호스트 정보",
              "value": "```\n'"$(hostname)"'\n```",
              "inline": false
            },
            {
              "name": "🖼️ 이미지",
              "value": "'"$IMAGE:latest"'",
              "inline": false
            }, 
            {
              "name": "📊 로컬 다이제스트",
              "value": "```\n'"$LOCAL_DIGEST"'\n```",
              "inline": false
            },
            {
              "name": "📊 원격 다이제스트",
              "value": "```\n'"$REMOTE_DIGEST"'\n```",
              "inline": false
            },
            {
              "name": "⏰ 실패 시간",
              "value": "'"$(TZ='Asia/Seoul' date '+%Y-%m-%d %H:%M:%S')"'",
              "inline": false
            }
          ],
          "footer": {
            "text": "🚫 새 이미지 Pull 실패 - 수동 조치가 필요합니다"
          }
        }]
      }' "$WEBHOOK_URL_AI"
    fi
  else
    # 3. 원격 저장소에서 이미지 메타데이터 확인 (개선된 함수 사용)
    REMOTE_DIGEST=$(get_remote_digest "$IMAGE" | tr -d '[:space:]') 
    log_message "  원격 다이제스트 값: <$REMOTE_DIGEST>" # 값 확인용 로그

    # 4. 로컬 이미지 정보 가져오기 (개선된 함수 사용)
    LOCAL_DIGEST=$(get_local_digest "$IMAGE:latest" | tr -d '[:space:]')
    log_message "  로컬 다이제스트 값: <$LOCAL_DIGEST>" # 값 확인용 로그

    # 디버깅 로그 개선 -> log_message 사용으로 변경
    log_message "[비교] 다이제스트 정보:"
    log_message "  원격: <$REMOTE_DIGEST>"
    log_message "  로컬: <$LOCAL_DIGEST>"

    # 비교 전 다이제스트 유효성 검사 강화
    if [ -z "$REMOTE_DIGEST" ] || [ -z "$LOCAL_DIGEST" ]; then
      log_message "⚠️ 다이제스트 정보 불완전함 - 업데이트 건너뜀 (원격: '$REMOTE_DIGEST', 로컬: '$LOCAL_DIGEST')"
      if [ -n "$LOCAL_DIGEST" ] && [ -n "$CONTAINER_RUNNING" ]; then
        save_working_image "$CONTAINER_RUNNING"
      fi
      sleep 60
      continue
    fi
    
    # 5. 정확한 Schema-2 Manifest 다이제스트 비교
    if [ "$REMOTE_DIGEST" = "$LOCAL_DIGEST" ]; then
      log_message "✅ 다이제스트 일치 - 업데이트 불필요"
      # 일치 시에도 현재 작동 이미지 저장 (롤백 대비)
      save_working_image "$CONTAINER_RUNNING"
    else
      log_message "🔄 다이제스트 불일치 감지!"
      log_message "  원격: <$REMOTE_DIGEST>"
      log_message "  로컬: <$LOCAL_DIGEST>"
      log_message "▶ 이미지 pull 및 재시작 중..."
      
      # 웹훅으로 업데이트 시작 알림 및 다이제스트 정보 전송
      curl -H "Content-Type: application/json" -X POST -d '{
        "username": "🤖 PUMATI 인공지능 배포 봇",
        "avatar_url": "https://avatars.githubusercontent.com/u/583231",
        "content": "🔄 **이미지 업데이트 시작** - '"$(hostname)"'",
        "embeds": [{
          "title": "🔍 새 이미지 감지됨",
          "color": 3447003,
          "description": "다이제스트 변경이 감지되어 이미지 업데이트를 시작합니다.",
          "fields": [
            {
              "name": "🖥️ 호스트 정보",
              "value": "```\n'"$(hostname)"'\n```",
              "inline": false
            },
            {
              "name": "🖼️ 이미지",
              "value": "'"$IMAGE:latest"'",
              "inline": false
            },
            {
              "name": "📊 로컬 다이제스트",
              "value": "```\n'"$LOCAL_DIGEST"'\n```",
              "inline": false
            },
            {
              "name": "📊 원격 다이제스트",
              "value": "```\n'"$REMOTE_DIGEST"'\n```",
              "inline": false
            },
            {
              "name": "⏰ 시작 시간",
              "value": "'"$(TZ='Asia/Seoul' date '+%Y-%m-%d %H:%M:%S')"'",
              "inline": false
            }
          ],
          "footer": {
            "text": "🔄 이미지 업데이트 시작"
          }
        }]
      }' "$WEBHOOK_URL_AI"
      
      # 업데이트 전에 현재 작동 중인 이미지 저장 (롤백용)
      save_working_image "$CONTAINER_RUNNING"
      
      # 새 이미지 pull
      # if docker pull "$IMAGE:latest" > /dev/null 2>&1; then
      if docker pull "$IMAGE:latest"; then
        sleep 2 # 새 이미지 로드 대기

        # 새 이미지 다이제스트 확인 (불필요 문자 제거 포함)
        # NEW_LOCAL_DIGEST=$(get_local_digest "$IMAGE:latest" | tr -d '[:space:]')
        # log_message "  Pull 후 새 로컬 다이제스트: <$NEW_LOCAL_DIGEST>"

        # # 새 이미지 다이제스트 유효성 검사
        # if [ -z "$NEW_LOCAL_DIGEST" ]; then
        #   log_message "⚠️ 새 다이제스트를 가져올 수 없음 - 재시작 건너뜀"
        #   sleep 10
        #   continue
        # fi
        
        # # pull 후에 이미지 변경 감지 (이전 로컬 다이제스트와 새 다이제스트 비교)
        # # 주의: $LOCAL_DIGEST는 루프 시작 시점의 값임
        # if [ "$NEW_LOCAL_DIGEST" = "$LOCAL_DIGEST" ]; then
        #    log_message "⚠️ pull 후에도 다이제스트 변경 없음 (이전 로컬: <$LOCAL_DIGEST>, 새 로컬: <$NEW_LOCAL_DIGEST>) - 재시작 건너뜀"
        #    sleep 10
        #    continue
        # fi

        # 기존 컨테이너 중지 및 제거
        log_message "▶ 기존 컨테이너 중지/제거 중..."
        docker stop "$NAME" >/dev/null 2>&1
        docker rm "$NAME" >/dev/null 2>&1

        # 새 컨테이너 실행
        log_message "▶ 새 이미지로 컨테이너 시작 중..."
        if docker run --gpus all -d --restart unless-stopped --name "$NAME" -p 8080:8080 "$IMAGE:latest"; then
          log_message "✅ 새 이미지로 컨테이너 재시작 성공"
          
          # 현재 시간 (KST)
          CURRENT_TIME=$(TZ='Asia/Seoul' date '+%Y년 %m월 %d일 %H:%M:%S')
          
          # 이미지 정보 가져오기
          IMAGE_INFO=$(docker inspect "$IMAGE:latest" 2>/dev/null)
          IMAGE_CREATED=$(echo "$IMAGE_INFO" | jq -r '.[0].Created')
          IMAGE_SIZE=$(echo "$IMAGE_INFO" | jq -r '.[0].Size')
          IMAGE_SIZE_GB=$(echo "scale=2; $IMAGE_SIZE/1024/1024/1024" | bc)
          
          # 깃헙 정보 가져오기 (CI에서 추가한 레이블)
          GIT_AUTHOR=$(docker inspect "$IMAGE:latest" | jq -r '.[0].Config.Labels.git_author // "알 수 없음"')
          GIT_COMMIT=$(docker inspect "$IMAGE:latest" | jq -r '.[0].Config.Labels.git_commit // "알 수 없음"')
          GIT_MESSAGE=$(docker inspect "$IMAGE:latest" | jq -r '.[0].Config.Labels.git_message // "알 수 없음"')
          
          # Discord 웹훅 페이로드 - 업데이트 성공
          curl -H "Content-Type: application/json" -X POST -d '{
            "username": "🤖 PUMATI 인공지능 배포 봇",
            "avatar_url": "https://avatars.githubusercontent.com/u/583231",
            "content": "🌟 **'"$GIT_AUTHOR"'** 님이 푸시한 AI 서비스가 업데이트되었습니다! 🚀",
            "embeds": [{
              "title": "✅ AI 서비스 업데이트 성공! 🎉 🎊",
              "color": 3066993,
              "description": "🔥 **'"$GIT_AUTHOR"'** 님이 푸시한 코드의 Docker 이미지로 업데이트가 성공적으로 완료되었습니다! 🙌",
              "fields": [
                {
                  "name": "👨‍💻 푸시한 사람 👑",
                  "value": "```fix\n'"$GIT_AUTHOR"'\n```",
                  "inline": false
                },
                {
                  "name": "📝 커밋 메시지 💬",
                  "value": "📌 '"$GIT_MESSAGE"' 📎",
                  "inline": false
                },
                {
                  "name": "🖥️ 호스트 정보 💻",
                  "value": "```fix\n'"$(hostname)"'\n```",
                  "inline": false
                },
                {
                  "name": "🕒 업데이트 시간 ⏰",
                  "value": "🗓️ '"$CURRENT_TIME"' 🕰️",
                  "inline": true
                },
                {
                  "name": "🖼️ 이미지 정보 📦",
                  "value": "```\n이미지: '"$IMAGE"'\n크기: '"$IMAGE_SIZE_GB"' GB\n커밋: '"$GIT_COMMIT"'\n```",
                  "inline": false
                },
                {
                  "name": "📊 다이제스트 변경",
                  "value": "```\n이전: '"$LOCAL_DIGEST"'\n새로: '"$NEW_LOCAL_DIGEST"'\n```",
                  "inline": false
                }
              ],
              "thumbnail": {
                "url": "https://robohash.org/'"$GIT_AUTHOR"'?set=set3&size=128x128"
              },
              "footer": {
                "text": "🏆 ktb8team AI 서비스 배포 시스템 - '"$(hostname)"' 🛠️"
              }
            }]
          }' "$WEBHOOK_URL_AI"
          
          # 이미지 배포 후 오래된 이미지 정리 (최신 3개 유지)
          OLD_IMAGES=$(docker images "$IMAGE" --format "{{.ID}}" | grep -v "$(docker inspect -f '{{.Id}}' "$IMAGE:latest")" | tail -n +4)
          if [ -n "$OLD_IMAGES" ]; then
            echo "[$TIMESTAMP] 🧹 새 이미지 배포 완료 후 오래된 이미지 정리 중..." | tee -a "$LOGFILE"
            echo "$OLD_IMAGES" | xargs -r docker rmi -f >> "$LOGFILE" 2>&1
          fi
        else
          log_message "❌ 컨테이너 재시작 실패" | tee -a "$LOGFILE"
          
          # 실패 시 로그 수집 (최대 50줄)
          CONTAINER_LOGS="$(docker logs $NAME 2>&1 | tail -n 50 || echo '로그를 가져올 수 없습니다')"
          
          # 상세 에러 메시지를 Discord로 전송
          curl -H "Content-Type: application/json" -X POST -d '{
            "username": "🤖 PUMATI 인공지능 배포 봇",
            "avatar_url": "https://avatars.githubusercontent.com/u/583231",
            "content": "🚨 **컨테이너 재시작 실패** - '"$(hostname)"'",
            "embeds": [{
              "title": "❌ 컨테이너 재시작 실패",
              "color": 16711680,
              "description": "새 이미지로 AI 서비스 컨테이너를 재시작하는 데 실패했습니다.",
              "fields": [
                {
                  "name": "🖥️ 호스트 정보",
                  "value": "```\n'"$(hostname)"'\n```",
                  "inline": false
                },
                {
                  "name": "🖼️ 이미지",
                  "value": "'"$IMAGE:latest"'",
                  "inline": false
                },
                {
                  "name": "📊 새 이미지 다이제스트",
                  "value": "```\n'"$NEW_LOCAL_DIGEST"'\n```",
                  "inline": false
                },
                {
                  "name": "📊 이전 이미지 다이제스트",
                  "value": "```\n'"$LOCAL_DIGEST"'\n```",
                  "inline": false
                },
                {
                  "name": "⏰ 실패 시간",
                  "value": "'"$(TZ='Asia/Seoul' date '+%Y-%m-%d %H:%M:%S')"'",
                  "inline": false
                },
                {
                  "name": "📄 컨테이너 로그",
                  "value": "```\n'$(echo "$CONTAINER_LOGS" | head -c 1000)'\n```",
                  "inline": false
                }
              ],
              "footer": {
                "text": "🚫 컨테이너 재시작 실패 - 수동 조치가 필요합니다"
              }
            }]
          }' "$WEBHOOK_URL_AI"
          
          # 롤백 시도 - 이전에 작동하던 컨테이너가 있다면 이미지 ID 저장
          LAST_WORKING_IMAGE_PATH="/tmp/last_working_image_id.txt"
          if [ -f "$LAST_WORKING_IMAGE_PATH" ]; then
            LAST_WORKING_IMAGE=$(cat "$LAST_WORKING_IMAGE_PATH")
            echo "[$TIMESTAMP] 🔄 이전 작동 이미지로 롤백 시도 중: $LAST_WORKING_IMAGE" | tee -a "$LOGFILE"
            
            if docker run --gpus all -d --restart unless-stopped --name "$NAME" -p 8080:8080 "$LAST_WORKING_IMAGE"; then
              log_message "✅ 이전 이미지로 롤백 성공" | tee -a "$LOGFILE"
              
              # 롤백 성공 알림
              curl -H "Content-Type: application/json" -X POST -d '{
                "username": "🤖 PUMATI 인공지능 배포 봇",
                "avatar_url": "https://avatars.githubusercontent.com/u/583231",
                "content": "🔄 **자동 롤백 성공** - '"$(hostname)"'",
                "embeds": [{
                  "title": "✅ 이전 버전으로 롤백 완료",
                  "color": 3066993,
                  "description": "새 이미지 시작 실패 후 이전 작동 버전으로 자동 롤백되었습니다.",
                  "fields": [
                    {
                      "name": "🖥️ 호스트 정보",
                      "value": "```\n'"$(hostname)"'\n```",
                      "inline": false
                    },
                    {
                      "name": "🖼️ 롤백된 이미지",
                      "value": "'"$LAST_WORKING_IMAGE"'",
                      "inline": false
                    },
                    {
                      "name": "⏰ 롤백 시간",
                      "value": "'"$(TZ='Asia/Seoul' date '+%Y-%m-%d %H:%M:%S')"'",
                      "inline": false
                    }
                  ],
                  "footer": {
                    "text": "🔄 자동 롤백 완료 - 수정된 이미지로 다시 배포해야 합니다"
                  }
                }]
              }' "$WEBHOOK_URL_AI"
            else
              log_message "❌ 롤백 실패" | tee -a "$LOGFILE"
            fi
          fi
        fi
      else
        echo "[$TIMESTAMP] 변경 없음 - 다이제스트 일치" >> "$LOGFILE"
        # 서비스가 정상 작동 중인 경우 현재 이미지 ID 저장 (롤백용)
        save_working_image "$CONTAINER_RUNNING"
      fi
    fi
  fi

  sleep 10
done # while 루프 종료
EOT

# 실행 권한 부여
chmod +x /opt/monitoring/watcher.sh

# 로그 파일 생성
touch /var/log/image-watcher.log
chmod 644 /var/log/image-watcher.log

# systemd 서비스 파일 생성
cat <<EOF > /etc/systemd/system/docker-image-watcher.service
[Unit]
Description=Docker Image Update Watcher
After=docker.service network-online.target
Requires=docker.service
Wants=network-online.target

[Service]
Type=simple
# watcher.sh 스크립트 실행
ExecStart=/opt/monitoring/watcher.sh
# 실패 시 항상 재시작
Restart=always
RestartSec=60
# 환경 변수 전달 (Webhook URL, 서비스 계정 키 파일 경로, 이미지 이름, 컨테이너 이름, 로그 파일 경로)
Environment="WEBHOOK_URL_AI=${WEBHOOK_URL}"
Environment="KEY_FILE=/etc/sa/ktb8team-reader.json"
Environment="IMAGE=asia-east1-docker.pkg.dev/ktb8team-458916/ktb8team/dev/ai"
Environment="NAME=ai"
Environment="LOGFILE=/var/log/image-watcher.log"

[Install]
WantedBy=multi-user.target
EOF

# 서비스 등록 및 시작
log_message "▶ 도커 이미지 감시 서비스 시작 중..."
systemctl daemon-reload
systemctl enable docker-image-watcher
systemctl start docker-image-watcher

# 서비스 상태 확인
if systemctl is-active --quiet docker-image-watcher; then
  log_message "✅ 도커 이미지 감시 서비스 시작 완료"
else
  log_message "❌ 도커 이미지 감시 서비스 시작 실패"
  log_message "▶ 서비스 상태 확인 중..."
  systemctl status docker-image-watcher
  # 서비스 로그 마지막 20줄 출력
  journalctl -u docker-image-watcher --no-pager -n 20
fi

###################################
# 완료 알림 메타데이터 표시
###################################
log_message "✅ [완료] 스타트업 스크립트 실행 종료 - $(hostname)"
# 인스턴스 게스트 속성에 스크립트 완료 상태 표시
curl -X PUT "http://metadata.google.internal/computeMetadata/v1/instance/guest-attributes/startup-script/status" \
  -H "Metadata-Flavor: Google" \
  -d "DONE"

