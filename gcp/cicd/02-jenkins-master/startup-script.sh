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
# Bash 변수는 $변수명 형식 사용
SECRET_NAME="$(basename "$SECRET_ID")"    # jenkins-admin-credentials

debug_log "스크립트 시작: Secret ID=$SECRET_ID, Secret Name=$SECRET_NAME"

### 1. 시스템 점검 ###########################################################
log "시스템 점검 중..."
DISK_SPACE=$(df -h / | awk 'NR==2 {print $4}')
MEM_AVAILABLE=$(free -m | awk 'NR==2 {print $7}')
debug_log "사용 가능한 디스크 공간: $DISK_SPACE, 사용 가능한 메모리: $MEM_AVAILABLEMB"

### 2. 필수 패키지 설치 #####################################################
log "필수 패키지 설치 중..."
apt-get update -qq
apt-get install -y jq curl wget gnupg lsb-release openjdk-17-jdk
debug_log "✅ 필수 패키지 설치 완료"

### 3. Jenkins 저장소 추가 ##################################################
log "Jenkins 저장소 추가 중..."
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key |
  tee /usr/share/keyrings/jenkins-keyring.asc >/dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
https://pkg.jenkins.io/debian-stable binary/" \
  | tee /etc/apt/sources.list.d/jenkins.list >/dev/null
apt-get update -qq
debug_log "✅ Jenkins 저장소 추가 완료"

### 4. Secret Manager → admin 자격 정보 #####################################
log "관리자 자격 증명 가져오는 중..."

# 시크릿 가져오기
ADMIN_JSON="$(gcloud secrets versions access latest --secret="$SECRET_NAME" 2>&1)" || {
  debug_log "❌ 시크릿 가져오기 실패: $ADMIN_JSON"
  exit 1
}

# JSON 형식 확인 및 내용 출력
debug_log "✅ 시크릿 JSON 내용: $ADMIN_JSON"

# 직접 키에서 값 추출
ADMIN_USER=$(echo "$ADMIN_JSON" | jq -r '.jenkins_admin_username')
ADMIN_PASS=$(echo "$ADMIN_JSON" | jq -r '.jenkins_admin_password')

debug_log "✅ 사용할 관리자 계정: 사용자='$ADMIN_USER', 비밀번호='$ADMIN_PASS'"

# 값이 없으면 오류
if [[ -z "$ADMIN_USER" || "$ADMIN_USER" == "null" || -z "$ADMIN_PASS" || "$ADMIN_PASS" == "null" ]]; then
  debug_log "❌ 관리자 계정 정보를 시크릿에서 찾을 수 없습니다"
  debug_log "시크릿의 JSON 형식은 다음과 같아야 합니다: {\"jenkins_admin_username\": \"admin\", \"jenkins_admin_password\": \"your_password\"}"
  exit 1
fi

### 5. Jenkins 서비스 준비 ##################################################
log "Jenkins 서비스 준비 중..."

# Jenkins 비활성화 (기존 서비스가 있는 경우)
systemctl stop jenkins || true
systemctl mask jenkins || true
debug_log "✅ Jenkins 서비스 비활성화 완료"

# Jenkins 홈 디렉토리 준비
JENKINS_HOME="/var/lib/jenkins"
mkdir -p "$JENKINS_HOME/init.groovy.d"

# Setup Wizard 상태 파일 생성
mkdir -p "$JENKINS_HOME"
touch "$JENKINS_HOME/jenkins.install.InstallUtil.lastExecVersion"
echo "2.504.1" > "$JENKINS_HOME/jenkins.install.InstallUtil.lastExecVersion"

# Groovy 초기화 스크립트 준비
cat > "$JENKINS_HOME/init.groovy.d/basic-security.groovy" <<EOF
import jenkins.model.*
import hudson.security.*
import jenkins.install.*

def instance = Jenkins.getInstance()

// 관리자 계정 생성
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount("$ADMIN_USER", "$ADMIN_PASS")
instance.setSecurityRealm(hudsonRealm)

// 인증 전략 설정
def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)

// Setup Wizard 비활성화
instance.setInstallState(InstallState.INITIAL_SETUP_COMPLETED)

instance.save()
EOF

# Setup Wizard 비활성화 스크립트
cat > "$JENKINS_HOME/init.groovy.d/disable-setup-wizard.groovy" <<EOF
import jenkins.model.*

def instance = Jenkins.getInstance()
instance.getSetupWizard().completeSetup()

// 초기 비밀번호 파일 삭제
def file = new File(instance.getRootDir(), "secrets/initialAdminPassword")
if (file.exists()) {
    file.delete()
}
EOF

chown -R jenkins:jenkins "$JENKINS_HOME"
chmod 750 "$JENKINS_HOME/init.groovy.d"/*.groovy
debug_log "✅ Jenkins 초기화 스크립트 준비 완료"

# Jenkins 환경 설정 파일
cat > /etc/default/jenkins <<EOF
# Jenkins 환경 설정

# Java 옵션
JAVA_ARGS="-Djava.awt.headless=true -Djenkins.install.runSetupWizard=false"

# Jenkins 옵션
JENKINS_ARGS="--webroot=/var/cache/jenkins/war --httpPort=8080"
EOF

debug_log "✅ Jenkins 환경 설정 파일 작성 완료"

### 6. Jenkins 설치 #########################################################
log "Jenkins 패키지 설치 중..."
# 패키지 설치 상세 로그 보기 위해 -qq 제거
DEBIAN_FRONTEND=noninteractive apt-get install -y jenkins
debug_log "✅ Jenkins 패키지 설치 완료"

### 7. Jenkins 서비스 활성화 ################################################
log "Jenkins 서비스 활성화 중..."
systemctl unmask jenkins
systemctl daemon-reload
systemctl enable jenkins
systemctl start jenkins

# 서비스 상태 확인
debug_log "✅ Jenkins 서비스 상태:"
debug_log "$(systemctl status jenkins || echo '서비스 상태 확인 실패')"

### 8. Jenkins 시작 대기 ####################################################
log "Jenkins 초기화 대기 중..."
WAIT_COUNT=0
MAX_WAIT=60  # 최대 10분 대기 (10초 간격)

# Jenkins가 시작될 때까지 대기
debug_log "Jenkins 시작 확인을 위해 대기 중..."
until $(curl -s -f -o /dev/null http://localhost:8080/login); do
  debug_log "Jenkins 시작 대기 중... ($((WAIT_COUNT + 1))/$MAX_WAIT)"
  sleep 10
  WAIT_COUNT=$((WAIT_COUNT + 1))
  
  # 로그 확인
  if [ $((WAIT_COUNT % 3)) -eq 0 ]; then
    debug_log "Jenkins 로그 확인:"
    debug_log "$(tail -n 10 /var/log/jenkins/jenkins.log 2>/dev/null || echo 'Jenkins 로그 파일 없음')"
  fi
  
  # 최대 대기 시간 초과
  if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
    debug_log "⚠️ Jenkins 시작 타임아웃, 상태 확인:"
    debug_log "$(systemctl status jenkins || echo '서비스 상태 확인 실패')"
    debug_log "$(tail -n 50 /var/log/jenkins/jenkins.log 2>/dev/null || echo 'Jenkins 로그 파일 없음')"
    break
  fi
done

# Jenkins 접속 확인
HTTP_STATUS=$(curl -s -o /dev/null -w "%http_code" http://localhost:8080/login || echo "접속 실패")
debug_log "Jenkins HTTP 상태: $HTTP_STATUS"

# initialAdminPassword 파일 확인 및 삭제
if [ -f "$JENKINS_HOME/secrets/initialAdminPassword" ]; then
  debug_log "⚠️ 초기 비밀번호 파일이 존재함, 강제 삭제 시도..."
  rm -f "$JENKINS_HOME/secrets/initialAdminPassword"
else
  debug_log "✅ 초기 비밀번호 파일 없음 (정상)"
fi

### 9. 플러그인 설치 (Jenkins가 정상 시작된 경우에만) #######################
if [ "$HTTP_STATUS" == "200" ]; then
  log "필수 플러그인 설치 중..."
  
  # CLI 다운로드
  wget -q -O /tmp/jenkins-cli.jar http://localhost:8080/jnlpJars/jenkins-cli.jar || {
    debug_log "❌ CLI 다운로드 실패"
  }
  
  # CLI 접속 테스트
  java -jar /tmp/jenkins-cli.jar -s http://localhost:8080/ -auth "$ADMIN_USER:$ADMIN_PASS" who-am-i && {
    debug_log "✅ CLI 인증 성공, 플러그인 설치 시작"
    
    # 플러그인 설치
    java -jar /tmp/jenkins-cli.jar -s http://localhost:8080/ \
      -auth "$ADMIN_USER:$ADMIN_PASS" install-plugin \
      workflow-aggregator git blueocean configuration-as-code \
      pipeline-model-definition pipeline-stage-view credentials-binding \
      ssh-agent ws-cleanup disk-usage cloudbees-folder matrix-auth \
      email-ext mailer dark-theme
    
    debug_log "✅ 플러그인 설치 완료, Jenkins 재시작 중..."
    
    # Jenkins 재시작
    java -jar /tmp/jenkins-cli.jar -s http://localhost:8080/ \
      -auth "$ADMIN_USER:$ADMIN_PASS" safe-restart
  } || {
    debug_log "❌ CLI 인증 실패, 플러그인 설치 생략"
  }
else
  debug_log "⚠️ Jenkins가 정상적으로 시작되지 않아 플러그인 설치를 건너뜁니다"
fi

### 10. 완료 배너 #############################################################
IP=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)

printf '\n==========================================================\n'
printf '✅  Jenkins ready:  http://%s:8080\n' "$IP"
printf '⭐  Login with: %s / %s\n' "$ADMIN_USER" "$ADMIN_PASS"
printf '==========================================================\n'

debug_log "스크립트 완료. Jenkins 접속 URL: http://$IP:8080"