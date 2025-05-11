#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  Jenkins 마스터 자동 구축 (GCE startup-script)
#  • Terraform templatefile() 로 $SECRET_ID 주입
#  • Secret Manager 의 JSON 값으로 admin 계정 생성
#  • Setup-Wizard 끄고 필수 플러그인 설치
# ---------------------------------------------------------------------------
set -euo pipefail
log() { printf '[%s] ▶ %s\n' "$(date +%FT%T%z)" "$*"; }
debug_log() { printf '[%s] 🔍 DEBUG: %s\n' "$(date +%FT%T%z)" "$*"; }

### 0. 변수 (Terraform 이 주입) #############################################
SECRET_ID="${secret_id}"                  # projects/.../jenkins-admin-credentials
SECRET_NAME="$(basename "$SECRET_ID")"    # jenkins-admin-credentials

debug_log "스크립트 시작: Secret ID=$SECRET_ID, Secret Name=$SECRET_NAME"

### 1. Jenkins 설치 ###########################################################
log "Installing prerequisites & Jenkins …"
apt-get update -qq
apt-get install -y jq curl wget gnupg lsb-release openjdk-17-jdk
# curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key |
#   tee /usr/share/keyrings/jenkins-keyring.asc >/dev/null
# echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
# https://pkg.jenkins.io/debian-stable binary/" \
#   | tee /etc/apt/sources.list.d/jenkins.list >/dev/null
# apt-get update -qq

# apt-get install -y jenkins
# systemctl stop jenkins  # apt 가 띄운 서비스 잠시 중단
# debug_log "Jenkins 설치 완료 및 서비스 중지됨"

# 1) 저장소 추가
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key |
  tee /usr/share/keyrings/jenkins-keyring.asc >/dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
https://pkg.jenkins.io/debian-stable binary/" \
  | tee /etc/apt/sources.list.d/jenkins.list >/dev/null
apt-get update -qq

# 2) 설치될 때 자동시작 막기
systemctl mask jenkins.service

# 3) 패키지 설치
apt-get install -y jenkins

# 4) 다시 자동시작 허용
systemctl unmask jenkins.service

debug_log "Jenkins 패키지 설치 완료 (아직 한 번도 기동되지 않음)"


### 2. Secret Manager → admin 자격 정보 #######################################
log "Fetching admin credentials …"

# 시크릿 가져오기
ADMIN_JSON="$(gcloud secrets versions access latest --secret="$SECRET_NAME" 2>&1)" || {
  debug_log "❌ 시크릿 가져오기 실패: $ADMIN_JSON"
  exit 1
}

# JSON 형식 확인 및 내용 출력
debug_log "✅ 시크릿 JSON 내용: $ADMIN_JSON"

# 직접 키에서 값 추출 (둘 중 하나만 사용)
ADMIN_USER=$(echo "$ADMIN_JSON" | jq -r '.jenkins_admin_username')
ADMIN_PASS=$(echo "$ADMIN_JSON" | jq -r '.jenkins_admin_password')

debug_log "✅ 사용할 관리자 계정: 사용자='$ADMIN_USER', 비밀번호='$ADMIN_PASS'"

# 값이 없으면 오류
if [[ -z "$ADMIN_USER" || "$ADMIN_USER" == "null" || -z "$ADMIN_PASS" || "$ADMIN_PASS" == "null" ]]; then
  debug_log "❌ 관리자 계정 정보를 시크릿에서 찾을 수 없습니다"
  debug_log "시크릿의 JSON 형식은 다음과 같아야 합니다: {\"jenkins_admin_username\": \"admin\", \"jenkins_admin_password\": \"your_password\"}"
  exit 1
fi

### 3. **/etc/default/jenkins** ― 한 번에 덮어쓰기 -----------------------------
log "Writing /etc/default/jenkins …"
cat >/etc/default/jenkins <<EOF

JAVA=/usr/bin/java

JAVA_ARGS="-Djava.awt.headless=true -Djenkins.install.runSetupWizard=false"
JENKINS_ARGS="--webroot=/var/cache/jenkins/war --httpPort=8080 --argumentsRealm.passwd.$ADMIN_USER=$ADMIN_PASS --argumentsRealm.roles.$ADMIN_USER=admin"

ADMIN_USER="$ADMIN_USER"
ADMIN_PASS="$ADMIN_PASS"
EOF

debug_log "✅ Jenkins 설정 파일 작성 완료"
debug_log "$(cat /etc/default/jenkins)"

### 4. Groovy init 스크립트 (admin 동기화) #####################################
install -o jenkins -g jenkins -d /var/lib/jenkins/init.groovy.d
cat >/etc/default/jenkins <<EOF
# --- credentials -------------------------------------------------
ADMIN_USER=$ADMIN_USER
ADMIN_PASS=$ADMIN_PASS

# --- JVM options (한 줄!) ----------------------------------------
JAVA_ARGS="-Djava.awt.headless=true -Djenkins.install.runSetupWizard=false \
-Djenkins.admin.user=$ADMIN_USER -Djenkins.admin.pass=$ADMIN_PASS"

# --- Jenkins options (한 줄!) ------------------------------------
JENKINS_ARGS="--webroot=/var/cache/jenkins/war --httpPort=8080 \
--argumentsRealm.passwd.$ADMIN_USER=$ADMIN_PASS \
--argumentsRealm.roles.$ADMIN_USER=admin"
EOF

chown -R jenkins:jenkins /var/lib/jenkins/init.groovy.d

debug_log "✅ Groovy 초기화 스크립트 작성 완료"
debug_log "$(ls -la /var/lib/jenkins/init.groovy.d/)"

# 초기 비밀번호 파일 제거 (있는 경우)
if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
  debug_log "초기 비밀번호 파일이 존재함, 내용: $(cat /var/lib/jenkins/secrets/initialAdminPassword)"
  rm -f /var/lib/jenkins/secrets/initialAdminPassword
  debug_log "✅ 초기 비밀번호 파일 삭제 완료"
else
  debug_log "초기 비밀번호 파일이 아직 생성되지 않음"
fi

### 5. Jenkins 기동 ###########################################################
log "Starting Jenkins …"
systemctl daemon-reload
systemctl enable --now jenkins

debug_log "✅ Jenkins 서비스 시작됨, 상태 확인:"
debug_log "$(systemctl status jenkins)"

# Jenkins 초기화 완료 확인
debug_log "Jenkins 초기화 대기 중..."
WAIT_COUNT=0
MAX_WAIT=30  # 30번 시도 (약 5분)

# --- 대기: 로그인 페이지 뜰 때까지
until curl -sf http://localhost:8080/login; do 
  debug_log "Jenkins 로그인 페이지 대기 중... ($WAIT_COUNT/$MAX_WAIT)"
  sleep 10
  WAIT_COUNT=$((WAIT_COUNT + 1))
  if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
    debug_log "❌ Jenkins 시작 타임아웃"
    debug_log "Jenkins 로그 확인:"
    debug_log "$(tail -n 100 /var/log/jenkins/jenkins.log)"
    break
  fi
done

sleep 10   # 내부 초기화 여유

# Jenkins 초기화 상태 확인
debug_log "Jenkins 파일 상태 확인:"
debug_log "$(ls -la /var/lib/jenkins/)"

# initialAdminPassword 파일 다시 확인
if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
  debug_log "❌ 초기 비밀번호 파일이 여전히 존재함: $(cat /var/lib/jenkins/secrets/initialAdminPassword)"
else
  debug_log "✅ 초기 비밀번호 파일이 없음 (정상)"
fi

### 6. CLI & 플러그인 ##########################################################
log "Installing plugins …"
wget -q -O /tmp/jenkins-cli.jar http://localhost:8080/jnlpJars/jenkins-cli.jar

debug_log "Jenkins CLI 연결 테스트:"
java -jar /tmp/jenkins-cli.jar -s http://localhost:8080/ -auth "$ADMIN_USER:$ADMIN_PASS" who-am-i || {
  debug_log "❌ Jenkins CLI 연결 실패"
  debug_log "Jenkins 웹 상태: $(curl -s -o /dev/null -w "%http_code" http://localhost:8080/)"
}

debug_log "플러그인 설치 시작..."
java -jar /tmp/jenkins-cli.jar -s http://localhost:8080/ \
  -auth "$ADMIN_USER:$ADMIN_PASS" install-plugin \
  workflow-aggregator git blueocean configuration-as-code \
  pipeline-model-definition pipeline-stage-view credentials-binding \
  ssh-agent ws-cleanup disk-usage cloudbees-folder matrix-auth \
  email-ext mailer dark-theme || {
    debug_log "❌ 플러그인 설치 실패"
  }

debug_log "Jenkins 재시작 시도..."
java -jar /tmp/jenkins-cli.jar -s http://localhost:8080/ \
  -auth "$ADMIN_USER:$ADMIN_PASS" safe-restart || {
    debug_log "❌ Jenkins 재시작 실패"
  }

### 7. 완료 배너 ###############################################################
IP=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)
printf '\n==========================================================\n'
printf '✅  Jenkins ready:  http://%s:8080 (admin / ******)\n' "$IP"
printf '==========================================================\n'

debug_log "스크립트 완료. Jenkins 접속 URL: http://$IP:8080"
