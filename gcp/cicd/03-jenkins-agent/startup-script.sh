#!/bin/bash
# Jenkins 에이전트 연결 스크립트
# 이 스크립트는 직접 Jenkins 마스터에 연결하여 에이전트를 등록합니다.

set -e

# 비대화형 모드 설정 - 패키지 설치 중 프롬프트 방지
export DEBIAN_FRONTEND=noninteractive

# 도구 설치
echo "▶ Installing prerequisites..."
apt-get update -y
apt-get install -y openjdk-17-jdk docker.io jq curl xmlstarlet

# Jenkins 유저 생성 및 Docker 그룹에 추가
useradd -m jenkins || echo "Jenkins user already exists"
usermod -aG docker jenkins

# 필요한 디렉토리 생성
mkdir -p /opt/jenkins
mkdir -p /var/jenkins_home
chown jenkins:jenkins /var/jenkins_home
chown jenkins:jenkins /opt/jenkins

# 영구 디스크 마운트
mount_disk() {
  local FORMAT_DISK="${format_disk:-false}"
  
  if [ -b /dev/disk/by-id/google-jenkins-agent-disk ]; then
    echo "▶ Found persistent disk..."
    
    # 디스크가 포맷되어 있는지 확인
    if ! blkid /dev/disk/by-id/google-jenkins-agent-disk; then
      if [ "$FORMAT_DISK" = "true" ]; then
        echo "▶ Formatting disk as requested via parameter..."
        mkfs.ext4 -m 0 -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/disk/by-id/google-jenkins-agent-disk
      else
        echo "❌ Disk appears to be unformatted, but auto-formatting is disabled."
        echo "❌ Please format the disk manually or set 'format_disk=true' parameter."
        return 1
      fi
    fi
    
    # 마운트 포인트 설정
    echo "▶ Mounting disk to /var/jenkins_home..."
    mount -o discard,defaults /dev/disk/by-id/google-jenkins-agent-disk /var/jenkins_home || {
      echo "❌ Mount failed."
      return 1
    }
    
    chown jenkins:jenkins /var/jenkins_home
    
    # /etc/fstab에 추가하여 부팅 시 자동 마운트
    if ! grep -q "jenkins-agent-disk" /etc/fstab; then
      echo "/dev/disk/by-id/google-jenkins-agent-disk /var/jenkins_home ext4 discard,defaults 0 2" >> /etc/fstab
    fi
    
    return 0
  else
    echo "❌ Error: Persistent disk not found, using local storage"
    return 1
  fi
}

# 디스코드 알림 설정
setup_discord_notifications() {
  echo "▶ Setting up spot instance termination notification..."
  
  # 시크릿 매니저에서 디스코드 웹훅 URL 가져오기
  local DISCORD_WEBHOOK_URL
  DISCORD_WEBHOOK_URL=$(gcloud secrets versions access latest --secret="discord-webhook-url" 2>/dev/null) || {
    echo "❌ Warning: Failed to retrieve Discord webhook URL, notifications will be disabled"
    return 1
  }
  
  if [ -z "$DISCORD_WEBHOOK_URL" ]; then
    echo "❌ Warning: Discord webhook URL is empty, notifications will be disabled"
    return 1
  }
  
  # 인스턴스 정보 가져오기
  local INSTANCE_NAME INSTANCE_ID ZONE
  INSTANCE_NAME=$(hostname)
  INSTANCE_ID=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/id)
  ZONE=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/zone | awk -F/ '{print $NF}')
  
  # 종료 감지 스크립트 생성
  cat > /usr/local/bin/spot-termination-handler <<EOF
#!/bin/bash

DISCORD_WEBHOOK_URL="$DISCORD_WEBHOOK_URL"
INSTANCE_NAME="$INSTANCE_NAME"
INSTANCE_ID="$INSTANCE_ID"
ZONE="$ZONE"

while true; do
  # GCP 스팟 인스턴스 종료 예약 확인
  METADATA_URL="http://metadata.google.internal/computeMetadata/v1/instance/maintenance-event"
  MAINTENANCE=\$(curl -s -H "Metadata-Flavor: Google" \$METADATA_URL || echo "NONE")
  
  if [[ "\$MAINTENANCE" == "TERMINATE_ON_HOST_MAINTENANCE" ]]; then
    echo "Spot instance termination detected!"
    
    # 현재 시간 (UTC)
    TIMESTAMP=\$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    
    # 디스코드로 알림 전송
    curl -s -H "Content-Type: application/json" -X POST "\$DISCORD_WEBHOOK_URL" \
      -d '{
        "embeds": [{
          "title": "⚠️ Jenkins 에이전트 종료 알림",
          "description": "스팟 인스턴스가 곧 종료됩니다",
          "color": 16711680,
          "fields": [
            {"name": "인스턴스 이름", "value": "'\$INSTANCE_NAME'", "inline": true},
            {"name": "인스턴스 ID", "value": "'\$INSTANCE_ID'", "inline": true},
            {"name": "영역", "value": "'\$ZONE'", "inline": true},
            {"name": "감지 시간", "value": "'\$TIMESTAMP'", "inline": false}
          ],
          "footer": {"text": "Jenkins CI/CD 모니터링"}
        }]
      }'
    
    # 로그 남기기
    echo "[\$(date)] Spot instance termination notification sent for \$INSTANCE_NAME (\$INSTANCE_ID)"
    
    # 알림 전송 후 60초 대기 후 종료 (재알림 방지)
    sleep 60
    exit 0
  fi
  
  # 30초마다 확인
  sleep 30
done
EOF
  
  chmod +x /usr/local/bin/spot-termination-handler
  
  # 백그라운드에서 종료 감지 스크립트 실행
  nohup /usr/local/bin/spot-termination-handler > /var/log/spot-termination-handler.log 2>&1 &
  
  echo "✅ Spot instance termination notification setup complete"
}

# 마스터 연결 성공 알림 전송
send_success_notification() {
  echo "▶ Sending agent connected notification..."
  
  # 시크릿 매니저에서 디스코드 웹훅 URL 가져오기
  local DISCORD_WEBHOOK_URL
  DISCORD_WEBHOOK_URL=$(gcloud secrets versions access latest --secret="discord-webhook-url" 2>/dev/null) || {
    echo "❌ Warning: Failed to retrieve Discord webhook URL, success notification will be skipped"
    return 1
  }
  
  if [ -z "$DISCORD_WEBHOOK_URL" ]; then
    echo "❌ Warning: Discord webhook URL is empty, success notification will be skipped"
    return 1
  }
  
  # 인스턴스 정보 가져오기
  local INSTANCE_NAME INSTANCE_ID ZONE MACHINE_TYPE
  INSTANCE_NAME=$(hostname)
  INSTANCE_ID=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/id)
  ZONE=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/zone | awk -F/ '{print $NF}')
  MACHINE_TYPE=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/machine-type | awk -F/ '{print $NF}')
  
  # 현재 시간 (UTC)
  local TIMESTAMP
  TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
  
  # 디스코드로 알림 전송
  curl -s -H "Content-Type: application/json" -X POST "$DISCORD_WEBHOOK_URL" \
    -d '{
      "embeds": [{
        "title": "✅ Jenkins 에이전트 연결 성공",
        "description": "새 스팟 인스턴스가 Jenkins 마스터에 연결되었습니다",
        "color": 65280,
        "fields": [
          {"name": "에이전트 이름", "value": "'"$AGENT_NAME"'", "inline": true},
          {"name": "인스턴스 이름", "value": "'"$INSTANCE_NAME"'", "inline": true},
          {"name": "인스턴스 ID", "value": "'"$INSTANCE_ID"'", "inline": true},
          {"name": "머신 타입", "value": "'"$MACHINE_TYPE"'", "inline": true},
          {"name": "영역", "value": "'"$ZONE"'", "inline": true},
          {"name": "연결 시간", "value": "'"$TIMESTAMP"'", "inline": false},
          {"name": "연결 URL", "value": "'"$JENKINS_URL/computer/$AGENT_NAME"'", "inline": false}
        ],
        "footer": {"text": "Jenkins CI/CD 모니터링"}
      }]
    }'
  
  echo "✅ Agent connected notification sent successfully"
}

# 영구 디스크 마운트 시도
mount_disk

# 변수 설정 - templatefile에서 전달된 변수 사용
JENKINS_URL="${jenkins_master_url}"

# 시크릿 매니저에서 Jenkins 관리자 계정 정보 가져오기
echo "▶ Retrieving Jenkins admin credentials from Secret Manager..."
JENKINS_ADMIN_CREDS=$(gcloud secrets versions access latest --secret="${jenkins_admin_secret_id}")
JENKINS_ADMIN_USERNAME=$(echo "$JENKINS_ADMIN_CREDS" | jq -r '.username')
JENKINS_ADMIN_PASSWORD=$(echo "$JENKINS_ADMIN_CREDS" | jq -r '.password')

if [[ -z "$JENKINS_ADMIN_USERNAME" || "$JENKINS_ADMIN_USERNAME" == "null" || -z "$JENKINS_ADMIN_PASSWORD" || "$JENKINS_ADMIN_PASSWORD" == "null" ]]; then
  echo "❌ Error: Failed to retrieve valid admin credentials"
  exit 1
fi
echo "✅ Retrieved Jenkins admin credentials successfully"

INSTANCE_ID=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/id)
AGENT_NAME="${agent_name}-${INSTANCE_ID:0:8}"  # 인스턴스 ID 사용하여 고유 이름 생성 (짧게 유지)
AGENT_WORKDIR="/var/jenkins_home"
LABELS="gcp docker linux llm-build spot"

# Jenkins CLI 다운로드
echo "▶ Downloading Jenkins CLI..."
curl -sL "$JENKINS_URL/jnlpJars/jenkins-cli.jar" -o /opt/jenkins/jenkins-cli.jar

# Jenkins 마스터에 직접 노드 생성 (CLI 사용)
echo "▶ Creating agent node on Jenkins master..."

# 노드 XML 구성 생성
cat > /opt/jenkins/agent-node.xml <<EOF
<?xml version="1.1" encoding="UTF-8"?>
<slave>
  <name>$AGENT_NAME</name>
  <description>Auto-provisioned GCP spot instance</description>
  <remoteFS>$AGENT_WORKDIR</remoteFS>
  <numExecutors>1</numExecutors>
  <mode>EXCLUSIVE</mode>
  <retentionStrategy class="hudson.slaves.RetentionStrategy\$Always"/>
  <launcher class="hudson.slaves.JNLPLauncher">
    <workDirSettings>
      <disabled>false</disabled>
      <internalDir>remoting</internalDir>
      <failIfWorkDirIsMissing>false</failIfWorkDirIsMissing>
    </workDirSettings>
  </launcher>
  <label>$LABELS</label>
  <nodeProperties/>
</slave>
EOF

# 노드가 이미 존재하는 경우 삭제 시도
java -jar /opt/jenkins/jenkins-cli.jar -s "$JENKINS_URL" -auth "$JENKINS_ADMIN_USERNAME:$JENKINS_ADMIN_PASSWORD" delete-node "$AGENT_NAME" || true

# 새 노드 생성
java -jar /opt/jenkins/jenkins-cli.jar -s "$JENKINS_URL" -auth "$JENKINS_ADMIN_USERNAME:$JENKINS_ADMIN_PASSWORD" create-node "$AGENT_NAME" < /opt/jenkins/agent-node.xml

# 시크릿 획득을 위해 JNLP 페이지 다운로드
echo "▶ Retrieving agent secret..."
curl -s -u "$JENKINS_ADMIN_USERNAME:$JENKINS_ADMIN_PASSWORD" "$JENKINS_URL/computer/$AGENT_NAME/jenkins-agent.jnlp" > /opt/jenkins/agent.jnlp

# JNLP 파일에서 시크릿 추출
AGENT_SECRET=$(xmlstarlet sel -t -v "//application-desc/argument[4]" /opt/jenkins/agent.jnlp)

if [ -z "$AGENT_SECRET" ]; then
  echo "❌ Error: Failed to retrieve agent secret. Trying alternate method..."
  # 두 번째 방법으로 시도 (JNLP 파일 파싱)
  AGENT_SECRET=$(grep -o '<argument>.*</argument>' /opt/jenkins/agent.jnlp | tail -1 | sed 's/<argument>\(.*\)<\/argument>/\1/')
  
  if [ -z "$AGENT_SECRET" ]; then
    echo "❌ Error: Could not retrieve agent secret by any method. Exiting."
    exit 1
  fi
fi

echo "✅ Successfully retrieved agent secret"

# Jenkins 에이전트 JAR 다운로드
echo "▶ Downloading Jenkins agent JAR..."
curl -sL "$JENKINS_URL/jnlpJars/agent.jar" -o /opt/jenkins/agent.jar

# systemd 서비스 파일 생성
echo "▶ Creating systemd service..."
cat > /etc/systemd/system/jenkins-agent.service <<EOF
[Unit]
Description=Jenkins Agent
After=network.target

[Service]
ExecStart=/usr/bin/java -jar /opt/jenkins/agent.jar -jnlpUrl "$JENKINS_URL/computer/$AGENT_NAME/slave-agent.jnlp" -secret "$AGENT_SECRET" -workDir "$AGENT_WORKDIR"
Restart=always
User=jenkins
Environment="JENKINS_HOME=$AGENT_WORKDIR"

[Install]
WantedBy=multi-user.target
EOF

# 서비스 활성화 및 시작
echo "▶ Enabling and starting service..."
systemctl daemon-reload
systemctl enable jenkins-agent
systemctl start jenkins-agent

# 디스코드 알림 설정 실행
setup_discord_notifications

# 서비스 상태 확인 (5초 대기 후)
echo "▶ Waiting for service to start..."
sleep 5

echo "▶ Service status:"
systemctl status jenkins-agent --no-pager

# 성공 알림 전송 (서비스가 실행 중인 경우만)
if systemctl is-active --quiet jenkins-agent; then
  echo "✅ Jenkins agent service started successfully"
  
  # 마스터 연결 성공 알림 전송
  send_success_notification
else
  echo "❌ Warning: Jenkins agent service failed to start properly"
fi

echo "✅ Jenkins agent setup completed"
echo "🔗 Connected to: $JENKINS_URL"
echo "👤 Agent name: $AGENT_NAME" 