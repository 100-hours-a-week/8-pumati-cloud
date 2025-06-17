#!/bin/bash

LOGFILE="/var/log/startup-script.log"
log_message() {
  local message="$1"
  local timestamp=$(TZ='Asia/Seoul' date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] $message" | tee -a $LOGFILE
  logger -t startup-script "$message"
}

log_message "✅ [시작] 스타트업 스크립트 실행 - 호스트명: $(hostname)"

# 내아이디 서비스계정 키파일 경로
KEY_FILE="/etc/sa/ktb8team-reader.json"

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

# 시스템 패키지 업데이트 (비대화 모드로 실행하여 프롬프트 방지)
log_message "▶ 시스템 패키지 업데이트 중..."
# DEBIAN_FRONTEND=noninteractive: 패키지 설치 시 사용자 입력 프롬프트 차단
# -yq: -y(자동 yes 응답) + -q(quiet 모드, 진행률 출력 최소화)
# dpkg 옵션들: 설정 파일 충돌 시 기본 동작 설정
if DEBIAN_FRONTEND=noninteractive apt-get update -yq && \
   DEBIAN_FRONTEND=noninteractive apt-get upgrade -yq \
   -o Dpkg::Options::="--force-confdef" \
   -o Dpkg::Options::="--force-confold"; then
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
  log_message "❌ 영구 디스크(/mnt/disks/pd)가 마운트되지 않아 GitHub Actions 러너 설치를 건너뜀니다."
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

# # Base64 디코딩하여 파일로 저장
# # 디코딩 실패 시 오류를 명확히 알 수 있도록 set -e 와 유사하게 처리
# if ! echo "${SA_KEY_CONTENT_BASE64}" | base64 --decode > /etc/sa/ktb8team-reader.json; then
#   log_message "❌ Base64 디코딩 실패 또는 파일 쓰기 실패."
#   # 디코딩 시도한 내용의 일부를 로그로 남겨 디버깅 (앞 100자)
#   log_message "   SA_KEY_CONTENT_BASE64 변수 내용 (일부): $(echo "${SA_KEY_CONTENT_BASE64}" | head -c 100)"
#   curl -H "Content-Type: application/json" \
#        -X POST \
#        -d "{\"content\": \"🚨 서비스 계정 키 Base64 디코딩 실패: 호스트 $(hostname)\"}" \
#        "${WEBHOOK_URL}"
#   exit 1
# fi
# chmod 600 /etc/sa/ktb8team-reader.json

# 파일 또는 디렉토리 여부 확인 후 확실히 삭제 rm -rf 사용해서.
log_message "▶ 서비스 계정 키 파일 경로 정리 중..."
rm -rf "/etc/sa/ktb8team-reader.json"  # 파일이든 디렉토리든 강제 삭제

# 디렉토리 확실히 생성
mkdir -p "/etc/sa"

# 이제 항상 파일 생성 시도
# ktb8team-reader.json 에다가 BASE64 디코딩 된 키 내용을 저장.
log_message "▶ 서비스 계정 키 파일 생성 중..."
if ! echo "${SA_KEY_CONTENT_BASE64}" | base64 --decode > "/etc/sa/ktb8team-reader.json"; then
  log_message "❌ Base64 디코딩 실패 또는 파일 쓰기 실패."
  exit 1
fi

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

# /root/.docker 디렉토리가 존재하고 파일이 아니라 디렉토리인지 확인 및 생성
if [ -f "/root/.docker" ]; then # 만약 /root/.docker 가 파일이라면
  log_message "⚠️ /root/.docker 가 파일로 잘못 존재하여 삭제하고 디렉토리로 재생성합니다."
  rm -f "/root/.docker" # 파일을 삭제
  mkdir -p "/root/.docker" # 디렉토리 생성
elif [ ! -d "/root/.docker" ]; then # 만약 /root/.docker 디렉토리가 아예 없다면
  log_message "ℹ️ /root/.docker 디렉토리가 없어 생성합니다."
  mkdir -p "/root/.docker" # 디렉토리 생성
fi

# /root/.docker/config.json 이 디렉토리로 잘못 생성되었다면 삭제
if [ -d "/root/.docker/config.json" ]; then # 만약 /root/.docker/config.json 이 디렉토리라면
  log_message "⚠️ /root/.docker/config.json 이 디렉토리로 잘못 존재하여 강제로 삭제합니다."
  rm -rf "/root/.docker/config.json" # 디렉토리를 강제로 삭제 (내용물 포함)
fi

# gcloud auth configure-docker 대신 docker login 직접 사용 
# 서비스 계정 키 파일을 사용하여 Docker 로그인 - 이 방식이 Watchtower에 더 잘 작동함
log_message "▶ Docker에 서비스 계정으로 직접 로그인 중..."
if cat "$KEY_FILE" | docker login -u _json_key --password-stdin https://asia-east1-docker.pkg.dev; then
  log_message "✅ Docker Artifact Registry 로그인 성공"
else
  log_message "❌ Docker Artifact Registry 로그인 실패"
  curl -H "Content-Type: application/json" \
       -X POST \
       -d "{\"content\": \"🚨 Docker Artifact Registry 로그인 실패: 호스트 $(hostname)\"}" \
       "${WEBHOOK_URL}"
  exit 1
fi

# 로그인 확인
if [ ! -f "/root/.docker/config.json" ]; then
  log_message "❌ Docker 로그인 후에도 config.json 파일이 생성되지 않았습니다."
  exit 1
else
  log_message "✅ Docker 로그인 설정 파일 생성 확인: /root/.docker/config.json"
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
# Watchtower가 이 컨테이너를 감시할 수 있도록 라벨 추가: -l com.centurylinklabs.watchtower.enable=true
if docker run --gpus all -d --restart unless-stopped --name ai -p 8080:8080 -l com.centurylinklabs.watchtower.enable=true "$IMAGE:latest"; then
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
# 9-1. 크롤링 서비스 cron 작업 설정 (수정됨)
###################################
log_message "▶ 크롤링 서비스 cron 작업 설정 시작"

# 크롤링 서비스 이미지 pull
CRAWLING_IMAGE="asia-east1-docker.pkg.dev/ktb8team-458916/ktb8team/dev/crawling"

log_message "▶ 크롤링 서비스 이미지 다운로드 중..."
if docker pull "$CRAWLING_IMAGE:latest"; then
  log_message "✅ 크롤링 이미지 다운로드 성공: $CRAWLING_IMAGE:latest"
else
  log_message "❌ 크롤링 이미지 다운로드 실패"
  curl -H "Content-Type: application/json" \
       -X POST \
       -d "{\"content\": \"🚨 크롤링 이미지 다운로드 실패: 호스트 $(hostname)에서 $CRAWLING_IMAGE:latest를 가져올 수 없습니다.\"}" \
       "${WEBHOOK_URL}"
  # 크롤링 서비스 실패는 전체 스크립트를 중단시키지 않음 (AI 서비스는 이미 실행 중)
fi

# 크롤링 실행 스크립트 생성
log_message "▶ 크롤링 실행 스크립트 생성 중..."
mkdir -p /opt/crawling
cat <<EOF > /opt/crawling/run-crawling.sh
#!/bin/bash

# 로그 설정
CRAWLING_LOG="/var/log/crawling-cron.log"
log_crawling() {
  local message="\$1"
  local timestamp=\$(TZ='Asia/Seoul' date '+%Y-%m-%d %H:%M:%S')
  echo "[\$timestamp] \$message" | tee -a \$CRAWLING_LOG
}

log_crawling "📊 크롤링 작업 시작"

# 기존 크롤링 컨테이너 정리 (만약 있다면)
docker stop crawling >/dev/null 2>&1 || true
docker rm crawling >/dev/null 2>&1 || true

# 크롤링 컨테이너 실행 (한 번만 실행 후 종료)
# --rm 제거: 로그 보존을 위해 컨테이너를 남겨두고 다음 실행 시 정리
# --restart 옵션 제거: 계속 실행하지 않음
log_crawling "▶ 크롤링 컨테이너 실행 중..."
if docker run --name crawling --network host \
  -e DISABLE_HTTP_SERVER=true \
  "$CRAWLING_IMAGE:latest"; then
  
  log_crawling "✅ 크롤링 작업 완료"
  
  # 성공 알림 전송
  curl -H "Content-Type: application/json" \
       -X POST \
       -d "{\"content\": \"✅ 크롤링 작업이 완료되었습니다. 호스트: \$(hostname), 시간: \$(TZ='Asia/Seoul' date '+%Y-%m-%d %H:%M:%S')\"}" \
       "${WEBHOOK_URL}"
else
  log_crawling "❌ 크롤링 작업 실패"
  
  # 실패 알림 전송
  curl -H "Content-Type: application/json" \
       -X POST \
       -d "{\"content\": \"🚨 크롤링 작업이 실패했습니다. 호스트: \$(hostname), 시간: \$(TZ='Asia/Seoul' date '+%Y-%m-%d %H:%M:%S')\"}" \
       "${WEBHOOK_URL}"
fi

log_crawling "🏁 크롤링 작업 종료"
EOF

# 스크립트 실행 권한 부여
chmod +x /opt/crawling/run-crawling.sh

# cron 작업 설정 (매일 오전 10시에 실행)
log_message "▶ 크롤링 cron 작업 설정 중 (매일 오전 10시)..."
(crontab -l 2>/dev/null || echo "") | grep -v "run-crawling" | { cat; echo "0 10 * * * /opt/crawling/run-crawling.sh"; } | crontab -

# 크롤링 로그 파일 생성
touch /var/log/crawling-cron.log
chmod 666 /var/log/crawling-cron.log

log_message "✅ 크롤링 cron 작업 설정 완료 (매일 오전 10시 실행)"
log_message "   • 로그 파일: /var/log/crawling-cron.log"
log_message "   • 수동 실행: /opt/crawling/run-crawling.sh"


###################################
# 7. 크로마디비(ChromaDB) 설치 및 설정
###################################
log_message "▶ 크로마디비 설치 및 설정 시작"

# 영구 디스크가 마운트되었는지 확인
if ! mount | grep -q "/mnt/disks/pd"; then
  log_message "❌ 영구 디스크(/mnt/disks/pd)가 마운트되지 않아 크로마디비 설정을 건너뜁니다."
else
  log_message "✅ 영구 디스크 확인됨. 크로마디비 데이터를 /mnt/disks/pd/chromadb에 저장합니다."
  
  # 크로마디비 데이터 디렉토리 생성
  CHROMA_DATA_DIR="/mnt/disks/pd/chromadb"
  mkdir -p "$CHROMA_DATA_DIR"
  
  # 크로마디비 설정 파일 저장 경로
  mkdir -p "/etc/chromadb"
  
  # 크로마디비 설정 파일 생성
  cat <<EOF > /etc/chromadb/config.yaml
chroma_server_host: "0.0.0.0"
chroma_server_http_port: 8000
chroma_server_cors_allow_origins: ["*"]
chroma_server_grpc_port: 50051
persist_directory: "$CHROMA_DATA_DIR"
allow_reset: true
anonymized_telemetry: false
EOF
  
  # 기존 크로마디비 컨테이너가 있다면 정리
  log_message "▶ 기존 크로마디비 컨테이너 정리 중..."
  docker rm -f chromadb >/dev/null 2>&1 || true
  
  # 크로마디비 컨테이너 실행
  log_message "▶ 크로마디비 컨테이너 시작 중..."
  if docker run -d --restart unless-stopped \
     --name chromadb \
     -p 8000:8000 \
     -v "$CHROMA_DATA_DIR:/chroma/chroma" \
     chromadb/chroma:0.4.24; then
     
    log_message "✅ 크로마디비 컨테이너 실행 성공"
    
    # 서비스 초기화 대기
    log_message "▶ 크로마디비 서비스 초기화 대기 중 (10초)..."
    sleep 10
    
    # 헬스체크
    for i in $(seq 1 5); do
      if curl -sf "http://localhost:8000/api/v1/heartbeat"; then
        log_message "✅ 크로마디비 서비스 응답 확인 (엔드포인트: /api/v1/heartbeat)"
        
        # 성공 알림 전송
        curl -H "Content-Type: application/json" \
             -X POST \
             -d "{\"content\": \"✅ 크로마디비가 설치되었습니다. 호스트: $(hostname), 포트: 8000, 데이터 경로: $CHROMA_DATA_DIR\"}" \
             "${WEBHOOK_URL}"
        break
      fi
      log_message "⏳ 크로마디비 헬스체크 재시도 $i/5..."
      sleep 5
    done
  else
    log_message "❌ 크로마디비 컨테이너 실행 실패"
    docker logs chromadb
    
    # 실패 알림 전송
    curl -H "Content-Type: application/json" \
         -X POST \
         -d "{\"content\": \"🚨 크로마디비 컨테이너 시작 실패: 호스트 $(hostname)\"}" \
         "${WEBHOOK_URL}"
  fi
fi

log_message "✅ 크로마디비 설정 완료"

###################################
# 7-1. 크로마디비 백업 설정
###################################
log_message "▶ 크로마디비 백업 스크립트 설정 중..."
mkdir -p /opt/backup

# 백업 및 복원 로그 파일 생성 및 권한 설정
touch /var/log/chromadb-backup.log
touch /var/log/chromadb-restore.log
chmod 666 /var/log/chromadb-backup.log
chmod 666 /var/log/chromadb-restore.log
log_message "✅ 백업 로그 파일 생성 및 권한 설정 완료"

cat <<EOF > /opt/backup/chromadb-backup.sh
#!/bin/bash

# 로그 설정
BACKUP_LOG="/var/log/chromadb-backup.log"

# 로그 파일 접근 권한 확인 및 수정
if [ ! -w "\$BACKUP_LOG" ]; then
  echo "로그 파일 권한 문제 발견. 수정 시도 중..."
  touch "\$BACKUP_LOG" 2>/dev/null || true
  chmod 666 "\$BACKUP_LOG" 2>/dev/null || true
  
  # 여전히 쓰기 권한이 없으면 /tmp로 전환
  if [ ! -w "\$BACKUP_LOG" ]; then
    BACKUP_LOG="/tmp/chromadb-backup.log"
    echo "로그 경로를 \$BACKUP_LOG로 변경합니다."
    touch "\$BACKUP_LOG"
  fi
fi

log_backup() {
  local message="\$1"
  local timestamp=\$(TZ='Asia/Seoul' date '+%Y-%m-%d %H:%M:%S')
  echo "[\$timestamp] \$message" | tee -a \$BACKUP_LOG
}

# 백업 파일명 설정 (날짜 포함)
BACKUP_DATE=\$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="/tmp/chromadb-backup-\$BACKUP_DATE.tar.gz"
CHROMA_DATA_DIR="$CHROMA_DATA_DIR"
GCS_BUCKET="ktb8team"
GCS_BACKUP_PATH="dev/backups/chromadb"
KEY_FILE="$KEY_FILE"  # 스타트업 스크립트에서 정의된 서비스 계정 키 파일 경로 사용

log_backup "크로마디비 백업 시작 (소스: \$CHROMA_DATA_DIR)"

# 백업 전 상태 확인
if [ ! -d "\$CHROMA_DATA_DIR" ]; then
  log_backup "❌ 백업 실패: 크로마디비 데이터 디렉토리(\$CHROMA_DATA_DIR)가 존재하지 않습니다."
  exit 1
fi

# 백업 생성
log_backup "▶ tar 파일 생성 중..."
tar -czf "\$BACKUP_FILE" -C "\$(dirname "\$CHROMA_DATA_DIR")" "\$(basename "\$CHROMA_DATA_DIR")"

if [ \$? -ne 0 ]; then
  log_backup "❌ tar 파일 생성 실패"
  exit 1
fi

log_backup "✅ 백업 파일 생성 완료: \$BACKUP_FILE (크기: \$(du -h "\$BACKUP_FILE" | cut -f1))"

# 서비스 계정으로 인증 (백업 작업용 임시 인증)
log_backup "▶ GCS 접근을 위한 서비스 계정 인증 중..."
export GOOGLE_APPLICATION_CREDENTIALS="\$KEY_FILE"
if ! gcloud auth activate-service-account --key-file="\$KEY_FILE" --quiet; then
  log_backup "❌ 서비스 계정 인증 실패"
  exit 1
fi

# GCS에 업로드
log_backup "▶ GCS 버킷(ktb8team)에 백업 파일 업로드 중..."
gsutil cp "\$BACKUP_FILE" "gs://\$GCS_BUCKET/\$GCS_BACKUP_PATH/chromadb-backup-\$BACKUP_DATE.tar.gz"

if [ \$? -ne 0 ]; then
  log_backup "❌ GCS 업로드 실패"
  exit 1
fi

log_backup "✅ GCS 업로드 완료: gs://\$GCS_BUCKET/\$GCS_BACKUP_PATH/chromadb-backup-\$BACKUP_DATE.tar.gz"

# 임시 파일 삭제
rm -f "\$BACKUP_FILE"
log_backup "✅ 임시 백업 파일 삭제 완료"

# 30일 이상 된 백업 정리 (옵션)
log_backup "▶ 오래된 백업 파일 정리 중..."
OLD_BACKUPS=\$(gsutil ls "gs://\$GCS_BUCKET/\$GCS_BACKUP_PATH/" | grep -E 'chromadb-backup-[0-9]{8}-[0-9]{6}\.tar\.gz' | sort | head -n -30)

if [ -n "\$OLD_BACKUPS" ]; then
  echo "\$OLD_BACKUPS" | xargs -I{} gsutil rm {}
  log_backup "✅ \$(echo "\$OLD_BACKUPS" | wc -l)개의 오래된 백업 파일 삭제 완료"
else
  log_backup "✅ 삭제할 오래된 백업 파일 없음"
fi

log_backup "🏁 크로마디비 백업 프로세스 완료"

# Discord 알림 전송
curl -H "Content-Type: application/json" \
     -X POST \
     -d "{\"content\": \"✅ 크로마디비 백업이 완료되었습니다. 서버: \$(hostname), 백업 파일: gs://\$GCS_BUCKET/\$GCS_BACKUP_PATH/chromadb-backup-\$BACKUP_DATE.tar.gz\"}" \
     "${WEBHOOK_URL}"
EOF

# 스크립트 실행 권한 부여
chmod +x /opt/backup/chromadb-backup.sh

# cron 작업 설정 (매일 21시에 실행) - root 사용자에 설정
log_message "▶ 크로마디비 백업 cron 작업 설정 중..."
(crontab -l 2>/dev/null || echo "") | grep -v "chromadb-backup" | { cat; echo "0 21 * * * /opt/backup/chromadb-backup.sh >> /var/log/chromadb-cron.log 2>&1"; } | crontab -

# 백업 복원 스크립트 생성 (필요시 수동 실행)
cat <<EOF > /opt/backup/chromadb-restore.sh
#!/bin/bash

# 로그 설정
RESTORE_LOG="/var/log/chromadb-restore.log"

# 로그 파일 접근 권한 확인 및 수정
if [ ! -w "\$RESTORE_LOG" ]; then
  echo "로그 파일 권한 문제 발견. 수정 시도 중..."
  touch "\$RESTORE_LOG" 2>/dev/null || true
  chmod 666 "\$RESTORE_LOG" 2>/dev/null || true
  
  # 여전히 쓰기 권한이 없으면 /tmp로 전환
  if [ ! -w "\$RESTORE_LOG" ]; then
    RESTORE_LOG="/tmp/chromadb-restore.log"
    echo "로그 경로를 \$RESTORE_LOG로 변경합니다."
    touch "\$RESTORE_LOG"
  fi
fi

log_restore() {
  local message="\$1"
  local timestamp=\$(TZ='Asia/Seoul' date '+%Y-%m-%d %H:%M:%S')
  echo "[\$timestamp] \$message" | tee -a \$RESTORE_LOG
}

# 인자 확인
if [ \$# -ne 1 ]; then
  log_restore "사용법: \$0 gs://버킷명/경로/백업파일.tar.gz"
  exit 1
fi

BACKUP_URL="\$1"
BACKUP_FILE="/tmp/chromadb-restore.tar.gz"
CHROMA_DATA_DIR="$CHROMA_DATA_DIR"
KEY_FILE="$KEY_FILE"  # 스타트업 스크립트에서 정의된 서비스 계정 키 파일 경로 사용

log_restore "▶ 크로마디비 복원 시작 (소스: \$BACKUP_URL, 대상: \$CHROMA_DATA_DIR)"

# 서비스 계정으로 인증 (복원 작업용 임시 인증)
log_restore "▶ GCS 접근을 위한 서비스 계정 인증 중..."
export GOOGLE_APPLICATION_CREDENTIALS="\$KEY_FILE"
if ! gcloud auth activate-service-account --key-file="\$KEY_FILE" --quiet; then
  log_restore "❌ 서비스 계정 인증 실패"
  exit 1
fi

# 백업 파일 다운로드
log_restore "▶ GCS에서 백업 파일 다운로드 중..."
gsutil cp "\$BACKUP_URL" "\$BACKUP_FILE"

if [ \$? -ne 0 ]; then
  log_restore "❌ 백업 파일 다운로드 실패"
  exit 1
fi

log_restore "✅ 백업 파일 다운로드 완료"

# 컨테이너 중지
log_restore "▶ 크로마디비 컨테이너 중지 중..."
docker stop chromadb || true

# 기존 데이터 백업 (안전을 위해)
if [ -d "\$CHROMA_DATA_DIR" ]; then
  TEMP_BACKUP="/tmp/chromadb_before_restore_\$(date +%Y%m%d-%H%M%S)"
  log_restore "▶ 기존 데이터 임시 백업 중: \$TEMP_BACKUP"
  cp -r "\$CHROMA_DATA_DIR" "\$TEMP_BACKUP"
fi

# 디렉토리 비우기
log_restore "▶ 기존 데이터 디렉토리 비우는 중..."
rm -rf "\$CHROMA_DATA_DIR"/*

# 백업 파일 압축 풀기
log_restore "▶ 백업 파일 압축 해제 중..."
mkdir -p "\$CHROMA_DATA_DIR"
tar -xzf "\$BACKUP_FILE" -C "/mnt/disks/pd"

if [ \$? -ne 0 ]; then
  log_restore "❌ 백업 파일 압축 해제 실패"
  exit 1
fi

log_restore "✅ 백업 파일 압축 해제 완료"

# 권한 설정
chown -R root:root "\$CHROMA_DATA_DIR"

# 컨테이너 재시작
log_restore "▶ 크로마디비 컨테이너 재시작 중..."
docker start chromadb

# 임시 파일 삭제
rm -f "\$BACKUP_FILE"
log_restore "✅ 임시 파일 삭제 완료"

log_restore "🏁 크로마디비 복원 프로세스 완료"

# Discord 알림 전송
curl -H "Content-Type: application/json" \
     -X POST \
     -d "{\"content\": \"✅ 크로마디비 복원이 완료되었습니다. 서버: \$(hostname), 복원 소스: \$BACKUP_URL\"}" \
     "${WEBHOOK_URL}"
EOF

# 복원 스크립트 실행 권한 부여
chmod +x /opt/backup/chromadb-restore.sh

# 크론 로그 파일 생성
touch /var/log/chromadb-cron.log
chmod 666 /var/log/chromadb-cron.log

log_message "✅ 크로마디비 백업 설정 완료 (매일 새벽 3시 자동 백업)"
log_message "   • 백업 파일: gs://ktb8team/dev/backups/chromadb/"
log_message "   • 복원 방법: /opt/backup/chromadb-restore.sh gs://ktb8team/dev/backups/chromadb/백업파일명.tar.gz"


###################################
# 10. Watchtower 자동 업데이트 설정
###################################
log_message "▶ Watchtower 자동 업데이트 설정 시작"

# 감시할 컨테이너 이름들 (AI 서비스만 - 크롤링은 cron으로 실행)
AI_CONTAINER_NAME="ai"
# Artifact Registry 인증을 위한 Docker 설정 파일 경로
# 이 파일은 스크립트의 섹션 9에서 'gcloud auth configure-docker' 명령어를 통해 생성/업데이트되었음.
# 스크립트가 root로 실행되므로 경로는 /root/.docker/config.json 임.
DOCKER_CONFIG_JSON_PATH="/root/.docker/config.json"

# Watchtower가 Docker 인증 설정 파일을 읽을 수 있는지 확인 (정보 제공용 로그)
if [ -f "$DOCKER_CONFIG_JSON_PATH" ]; then
  log_message "ℹ️ Docker 인증 설정 파일($DOCKER_CONFIG_JSON_PATH)이 확인되었습니다. Watchtower가 이를 사용합니다."
else
  # 이 경우 Watchtower는 private 레지스트리에서 이미지를 가져오는데 실패할 수 있습니다.
  log_message "⚠️ Docker 인증 설정 파일($DOCKER_CONFIG_JSON_PATH)을 찾을 수 없습니다. Watchtower가 Artifact Registry 인증에 실패할 수 있습니다."
  log_message "   스크립트의 이전 단계(섹션 9)에서 'gcloud auth configure-docker' 명령이 정상적으로 실행되었는지 확인이 필요합니다."
fi

# 기존 Watchtower 컨테이너가 있다면 정리 (스크립트 재실행 시 중복 방지)
log_message "▶ 기존 Watchtower 컨테이너(이름: watchtower)가 있다면 정리합니다..."
docker rm -f watchtower >/dev/null 2>&1 || true # 오류가 발생해도 다음 단계 진행

log_message "▶ Watchtower 컨테이너 실행 중 (감시 대상: $AI_CONTAINER_NAME)..."
# Watchtower 실행 명령어 및 옵션 설명:
# -d: 데몬 모드(백그라운드)로 실행
# --name watchtower: 컨테이너의 이름을 'watchtower'로 지정
# --restart=unless-stopped: Docker 데몬이 시작될 때나 컨테이너가 (오류 등으로) 종료되었을 때, 명시적으로 중지하지 않는 한 항상 재시작
# -v /var/run/docker.sock:/var/run/docker.sock: 호스트의 Docker 소켓을 컨테이너 내부에 마운트합니다. 이를 통해 Watchtower가 호스트의 Docker 데몬과 통신하여 다른 컨테이너를 관리할 수 있습니다.
# -v /root/.docker/config.json:/config.json:ro: 호스트의 Docker 인증 파일을 컨테이너 내부의 /config.json 경로로 읽기 전용(ro) 마운트합니다. 이 방식이 Artifact Registry 인증에 더 안정적입니다.
# -e WATCHTOWER_CONFIG=/config.json: Watchtower에게 컨테이너 내부의 /config.json 파일을 Docker 인증 설정으로 사용하도록 지시합니다.
# -e WATCHTOWER_POLL_INTERVAL=10: 이미지 업데이트를 확인하는 주기를 초 단위로 설정합니다 (여기서는 10초).
# -e WATCHTOWER_CLEANUP=true: 새 이미지로 업데이트한 후, 더 이상 사용되지 않는 이전 버전의 이미지를 자동으로 삭제합니다.
# -e WATCHTOWER_NOTIFICATIONS=shoutrrr: Watchtower에게 알림을 전송하는 방식을 'shoutrrr'로 설정합니다.
# -e WATCHTOWER_NOTIFICATION_URL="discord://...": 알림을 전송할 Discord 채널의 URL을 지정합니다.
# -e TZ=Asia/Seoul: 컨테이너 내의 시간대를 'Asia/Seoul'로 설정합니다. 이는 로그 메시지의 타임스탬프 등에 영향을 줍니다.
# "$AI_CONTAINER_NAME": Watchtower가 감시할 특정 컨테이너의 이름을 지정합니다. 여기서는 'ai' 컨테이너만 감시합니다.

# 서비스 계정 키 파일 경로 설정. 위쪽에서 설정했음.

# SERVICE_ACCOUNT_KEY_FILE_FOR_WATCHTOWER="$KEY_FILE"

# AI 채널 주소 알맞게 파싱한거
DISCORD_SHOUTRRR_URL="discord://7MMbnBH7R8OWuKyD-PjCQ8CLkv9TGjrh2kVQW4-4mspHy_z_OtsUfDrdxWvmvLTPcT0Y@1369931403055337586"

if docker run -d \
  --name watchtower \
  --restart=unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /root/.docker/config.json:/config.json:ro \
  -e WATCHTOWER_CONFIG=/config.json \
  -e WATCHTOWER_POLL_INTERVAL=10 \
  -e WATCHTOWER_CLEANUP=true \
  -e WATCHTOWER_NOTIFICATIONS=shoutrrr \
  -e WATCHTOWER_NOTIFICATION_URL="$DISCORD_SHOUTRRR_URL" \
  -e TZ=Asia/Seoul \
  containrrr/watchtower \
  "$AI_CONTAINER_NAME"; then
  # --- 디버깅: 명령어 실행 추적 종료 ---
  set +x
  log_message "✅ Watchtower 컨테이너 실행 성공!"
  # ... (기존 성공 로그) ...
  
  curl -H "Content-Type: application/json" \
       -X POST \
       -d "{\"content\": \"✅ Watchtower가 '$AI_CONTAINER_NAME' 컨테이너 자동 업데이트를 시작합니다. 호스트: $(hostname)\"}" \
       "${WEBHOOK_URL}"
else
  # --- 디버깅: 실패 시 종료 코드 로깅 ---
  EXIT_CODE=$?
  log_message "❌ Watchtower 컨테이너 실행 실패! (종료 코드: $EXIT_CODE)"
  # --- 디버깅: 명령어 실행 추적 종료 ---
  set +x
  log_message "   실패 원인 파악을 위해 Watchtower 컨테이너 로그(만약 생성되었다면) 또는 Docker 데몬 로그를 확인하세요."
  log_message "   이전 Docker 로그 (최대 20줄):"
  docker logs watchtower --tail 20 >> "$LOGFILE" 2>&1 || log_message "   (Watchtower 컨테이너 로그를 가져올 수 없음)"
  docker logs watchtower --tail 20 2>/dev/null || true # 콘솔에도 출력 시도
  
  # 실패 알림 (Discord)
  curl -H "Content-Type: application/json" \
       -X POST \
       -d "{\"content\": \"🚨 Watchtower 컨테이너 시작 실패! (종료 코드: $EXIT_CODE) 호스트: $(hostname). 자동 업데이트 작동 불가.\"}" \
       "${WEBHOOK_URL}" # 알림 URL 통일
fi


log_message "✅ Watchtower 자동 업데이트 설정 완료"

###################################
# 11. 오래된 Docker 이미지 정리 (추가)
###################################
log_message "▶ 일주일 이상 된 사용하지 않는 Docker 이미지 정리 시도..."
if docker image prune -a -f --filter "until=168h"; then # 168시간
  log_message "✅ 일주일 이상 된 사용하지 않는 Docker 이미지 정리 완료."
else
  log_message "⚠️ 일주일 이상 된 사용하지 않는 Docker 이미지 정리 중 오류 발생."
fi

# 스타트업 스크립트의 모든 주요 작업이 완료되었음을 알리는 최종 로그 메시지
log_message "🏁 [종료] 모든 스타트업 스크립트 작업이 완료되었습니다. 호스트명: $(hostname)"

# 테스트 백업 실행 (즉시 한 번)
log_message "▶ 설치 후 첫 백업 테스트 실행 중..."
/opt/backup/chromadb-backup.sh