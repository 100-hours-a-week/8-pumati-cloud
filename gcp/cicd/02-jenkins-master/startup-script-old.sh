#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Jenkins master 자동 구축 스크립트 (GCE startup-script)
#   • Terraform templatefile() 로 `${secret_id}` 주입
#   • Secret Manager 의 JSON 값으로 admin 계정 자동 생성
#   • Setup-Wizard 및 필수 플러그인 자동 구성
# ---------------------------------------------------------------------------
set -euo pipefail
log() { echo "[$(date +%FT%T%z)] ▶ $*"; }

##############################################################################
# 0. 변수 (Terraform 에서 주입)
##############################################################################
SECRET_ID="${secret_id}"          # projects/…/secrets/jenkins-admin-credentials
SECRET_NAME="$(basename "$SECRET_ID")"   # -> jenkins-admin-credentials

##############################################################################
# 1. Jenkins 저장소 & 패키지 설치
##############################################################################
log "Installing prerequisites …"
sudo apt-get update -qq
sudo apt-get install -y jq curl wget gnupg lsb-release openjdk-17-jdk

log "Adding Jenkins apt repository …"
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key |
  sudo tee /usr/share/keyrings/jenkins-keyring.asc >/dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
https://pkg.jenkins.io/debian-stable binary/" |
  sudo tee /etc/apt/sources.list.d/jenkins.list >/dev/null

log "Installing Jenkins …"
sudo apt-get update -qq
sudo apt-get install -y jenkins
sudo systemctl stop jenkins   # apt 가 띄운 서비스 즉시 중단

##############################################################################
# 2. Setup-Wizard 비활성화
##############################################################################
log "Disabling setup wizard …"
sudo sed -i '/runSetupWizard/d' /etc/default/jenkins
echo 'JAVA_ARGS="$JAVA_ARGS -Djenkins.install.runSetupWizard=false"' |
  sudo tee -a /etc/default/jenkins >/dev/null

##############################################################################
# 3. Secret Manager → admin 자격 정보 로드
##############################################################################
log "Fetching admin credentials from Secret Manager ($SECRET_NAME) …"
ADMIN_JSON=$(gcloud secrets versions access latest --secret="$SECRET_NAME")
ADMIN_USER=$(jq -r '.jenkins_admin_username' <<<"$ADMIN_JSON")
ADMIN_PASS=$(jq -r '.jenkins_admin_password' <<<"$ADMIN_JSON")

if [[ -z "$ADMIN_USER" || -z "$ADMIN_PASS" ]]; then
  log "❌  Secret 값이 비어 있거나 잘못되었습니다"
  exit 1
fi

##############################################################################
# 4. Groovy init 스크립트 작성 (admin 계정 + 권한)
##############################################################################
log "Preparing Groovy init script …"
sudo install -o jenkins -g jenkins -d /var/lib/jenkins/init.groovy.d

sudo tee /var/lib/jenkins/init.groovy.d/01-create-admin.groovy >/dev/null <<EOF
import jenkins.model.*
import hudson.security.*
import jenkins.install.InstallState

def j = Jenkins.get()

// ── 보안 영역 준비 ────────────────────────────────────────────────────────────
def realm = j.getSecurityRealm() instanceof HudsonPrivateSecurityRealm
           ? j.getSecurityRealm()
           : new HudsonPrivateSecurityRealm(false)

// ── admin 계정 생성/비번 갱신 ────────────────────────────────────────────────
def user = realm.getUser("$ADMIN_USER")
if (user == null) {
    realm.createAccount("$ADMIN_USER", "$ADMIN_PASS")
    println "--> created admin user ($ADMIN_USER)"
} else {
    def details = user.getProperty(HudsonPrivateSecurityRealm.Details)
    details.updatePassword("$ADMIN_PASS")      // ← 핵심!
    user.save()
    println "--> reset password for existing admin user ($ADMIN_USER)"
}


// ── 권한·설치 상태 설정 ──────────────────────────────────────────────────────
j.setSecurityRealm(realm)
j.setAuthorizationStrategy(new FullControlOnceLoggedInAuthorizationStrategy())
j.setInstallState(InstallState.INITIAL_SETUP_COMPLETED)
j.save()
EOF

sudo chown jenkins:jenkins /var/lib/jenkins/init.groovy.d/*.groovy

##############################################################################
# 5. Jenkins 기동 & 초기화 대기
##############################################################################
log "Starting Jenkins …"
sudo systemctl enable --now jenkins
until curl -sf http://localhost:8080/login >/dev/null; do sleep 5; done
sleep 10   # 내부 초기화 여유

##############################################################################
# 6. Jenkins CLI & 플러그인 설치
##############################################################################
log "Downloading Jenkins CLI …"
wget -q -O /tmp/jenkins-cli.jar http://localhost:8080/jnlpJars/jenkins-cli.jar

log "Installing plugins …"
java -jar /tmp/jenkins-cli.jar -s http://localhost:8080/ -auth "$ADMIN_USER:$ADMIN_PASS" install-plugin \
  workflow-aggregator git configuration-as-code blueocean \
  pipeline-model-definition pipeline-stage-view credentials-binding \
  ssh-agent ws-cleanup disk-usage cloudbees-folder antisamy-markup-formatter \
  build-timeout timestamper ant gradle pipeline-github github-branch-source \
  pipeline-github-lib pipeline-graph-analysis ssh matrix-auth pam-auth ldap \
  email-ext mailer dark-theme || true

log "Safe-restarting Jenkins …"
java -jar /tmp/jenkins-cli.jar -s http://localhost:8080/ -auth "$ADMIN_USER:$ADMIN_PASS" safe-restart || true
until curl -sf http://localhost:8080/login >/dev/null; do sleep 5; done

##############################################################################
# 7. 마무리 배너
##############################################################################
sudo rm -f /var/lib/jenkins/secrets/initialAdminPassword || true

EXTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)

cat <<EOM
==========================================================
✅  Jenkins 설치 완료!
🔗  URL      : http://$EXTERNAL_IP:8080
👤  Username : $ADMIN_USER
🔐  Password : $ADMIN_PASS
==========================================================
EOM


