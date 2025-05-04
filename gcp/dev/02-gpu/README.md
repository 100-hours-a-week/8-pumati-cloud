# CloudFlare Tunnel을 통한 GCP-AWS 연동 자동화

## 프로젝트 개요

테라폼 사용해서 gcp 인프라 구축:
- 단일 인스턴스(GPU 스팟 인스턴스)
- MIG 사용하여 스팟 인스턴스 종료 시 자동 재부팅
- 백업용 GCS 버킷 생성(로그, 모델 등)
- Cloudflare Tunnel을 통한 AWS 백엔드와의 안전한 연결

## 사전 준비 단계

### AWS 설정
- AWS CLI 설치 및 `aws configure` 를 통한 ktb8team 계정 설정

### Google Cloud CLI 설치 및 인증 (macOS)

#### 1. Google Cloud CLI 설치

**Homebrew를 사용한 설치 (권장)**
```bash
# Homebrew가 설치되어 있지 않다면, 먼저 설치
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Google Cloud CLI 설치
brew install --cask google-cloud-sdk
```

**수동 설치 (대안)**
```bash
# 설치 스크립트 다운로드 및 실행
curl https://sdk.cloud.google.com | bash

# 환경 변수 설정을 위해 쉘 재시작
exec -l $SHELL

# gcloud 명령이 정상 작동하는지 확인
gcloud --version
```

#### 2. GCP 계정 인증

**기본 사용자 계정으로 인증 (개발용)**
```bash
# 브라우저가 열리고 Google 계정으로 로그인 요청
gcloud auth login
```

#### 3. setup-terraform-sa.sh 실행

```bash
# 루트 디렉토리에 있는 setup-terraform-sa.sh 실행. 실행하면 terraform-key.json 파일이 생성됨
./setup-terraform-sa.sh
```

#### 4. 인증 확인(문제 생기면)

```bash
# 현재 인증된 계정 확인
gcloud auth list

# 현재 프로젝트 설정 확인
gcloud config list
```

## Cloudflare Tunnel 준비 작업

Terraform 실행 전에 아래 단계를 **한 번만** 수행해야 합니다.

### 1️⃣ Cloudflare Tunnel 생성 및 인증 정보 확보

#### 1-1. cloudflared 설치 (로컬)
```bash
brew install cloudflared  # macOS 기준
```

#### 1-2. Cloudflare 계정 인증
```bash
cloudflared login
```
- 웹 브라우저가 열리며 Cloudflare 계정 인증 진행
- 인증 후 `~/.cloudflared/cert.pem` 파일 생성됨

#### 1-3. Tunnel 생성
```bash
cloudflared tunnel create ai-tunnel
```
- `~/.cloudflared/ai-tunnel.json` 생성됨 (또는 `<UUID>.json` 형식)

#### 1-4. 도메인 라우팅 설정
```bash
cloudflared tunnel route dns ai-tunnel ai.mydairy.my
```
- Cloudflare DNS에 A/AAAA 레코드가 자동 생성됨

### 2️⃣ GCS에 Cloudflare 인증 파일 업로드

#### 2-1. 로컬에서 인증 정보 확인
```bash
ls ~/.cloudflared/
# cert.pem
# ai-tunnel.json (또는 <UUID>.json)
```

#### 2-2. 버킷 정보
- 버킷 이름: `your-bucket-name` (실제 배포 시 변경 필요)
- 위치: `your-preferred-region` (예: asia-east1)
- 저장 경로: `gs://your-bucket-name/cloudflared/`

#### 2-3. 인증 파일 업로드
```bash

gsutil cp ~/.cloudflared/cert.pem gs://your-bucket-name/cloudflared/
gsutil cp ~/.cloudflared/ai-tunnel.json 또는 <UUID>.json gs://your-bucket-name/cloudflared/

# 예시
gsutil cp ~/.cloudflared/cert.pem gs://ktb8team-static-storage/cloudflare/
gsutil cp ~/.cloudflared/33fe96b3-f223-4ac1-a18a-675fecfdda7d.json gs://ktb8team-static-storage/cloudflare/


```
- 버킷은 비공개이며, 버전 관리 활성화 및 소프트 삭제 사용 중
- GCP 인스턴스는 서비스 계정을 통해 접근

### 3️⃣ 확인 체크리스트

| 항목 | 확인 |
|------|------|
| cert.pem 파일 생성 완료 | ✔️ |
| llm-tunnel.json (또는 <UUID>.json) 생성 완료 | ✔️ |
| Cloudflare DNS에 도메인 등록 (llm.example.com) | ✔️ |
| GCS 버킷에 인증 파일 업로드 완료 | ✔️ |
| 버킷 이름 ktb8team-static-storage 및 경로 확인 | ✔️ |

## Terraform 자동화 내용

사전 준비가 완료되면 Terraform은 다음 작업을 자동으로 수행합니다:

1. GCP GPU 스팟 인스턴스 생성
2. 시작 스크립트를 통한 cloudflared 자동 설치
3. GCS 버킷에서 인증 파일 다운로드
4. systemd 유닛 파일 생성 및 서비스 등록
5. 부팅 시 Cloudflare Tunnel 자동 실행

## 테라폼 모듈 구조

- `dev/gcp/00-common`: 공통 변수 및 설정
- `dev/gcp/01-static`: 정적 스토리지 (GCS 버킷)
- `dev/gcp/02-main`: 메인 인프라 (GPU 인스턴스, MIG)
- `dev/gcp/modules`: 재사용 가능한 모듈 (compute, mig, gcs)

## Terraform 실행 방법

```bash
# 공통 모듈 배포
cd dev/gcp/00-common
terraform init
terraform apply

# 스토리지 배포
cd ../01-static
terraform init
terraform apply

# 컴퓨팅 인스턴스 배포
cd ../02-main
terraform init
terraform apply
```

## 02-main 배포 후 확인 및 테스트 가이드

인스턴스 배포 후 아래 단계에 따라 시스템 상태를 점검하고 문제를 해결합니다.

### 1. 인스턴스 상태 확인

```bash
# 인스턴스 목록 확인
gcloud compute instances list

# 인스턴스 상세 정보 확인
gcloud compute instances describe test-gpu-spot --zone=asia-east1-a
```

### 2. SSH 접속 및 스타트업 스크립트 로그 확인

```bash
# 인스턴스에 SSH 연결
gcloud compute ssh test-gpu-spot --zone=asia-east1-a

# 스타트업 스크립트 로그 확인
sudo cat /var/log/startup-script.log
```

스크립트 실행 로그에서 다음 내용을 확인하세요:
- `스타트업 스크립트 실행 시작` - 스크립트가 시작됨
- `cloudflared 설치 완료` - cloudflared 설치 성공
- `Cloudflare 서비스 시작됨` - cloudflared 서비스 실행
- `이미지 로드 성공` - Docker 이미지 로드
- `컨테이너 실행 성공` - Docker 컨테이너 실행
- `스타트업 스크립트 실행 완료` - 전체 스크립트 완료

### 3. cloudflared 서비스 상태 확인

```bash
# 서비스 상태 확인
sudo systemctl status cloudflared

# 서비스 로그 확인
sudo journalctl -u cloudflared -n 50
```

다음과 같은 출력이 정상 작동 상태를 나타냅니다:
- `Active: active (running)` - 서비스가 실행 중
- `Connected` 또는 `Connection` 메시지 - Cloudflare 서버와 연결됨

### 4. Docker 컨테이너 상태 확인 및 문제 해결

```bash
# 모든 컨테이너 확인 (실행/중지 모두)
sudo docker ps -a

# 다양한 포맷으로 확인
sudo docker ps -a --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
```

#### 4-1. 컨테이너가 없거나 종료된 경우

컨테이너가 보이지 않거나 `Exited` 상태인 경우:

```bash
# 가장 최근 종료된 컨테이너 로그 확인
sudo docker logs $(sudo docker ps -a -q | head -1)

# 이미지 상세 정보 확인
sudo docker inspect ai-test:latest
```

#### 4-2. 플랫폼 호환성 문제 해결

이미지와 호스트 아키텍처가 다른 경우(일반적으로 ARM64 이미지를 AMD64 호스트에서 실행):

```bash
# 이미지 플랫폼 확인
sudo docker inspect ai-test:latest | grep "Architecture\|Os"

# 호스트 아키텍처 확인
uname -m
```

문제가 발견되면 다음과 같이 해결:

```bash
# 기존 컨테이너 중지 및 삭제
sudo docker stop $(sudo docker ps -a -q)
sudo docker rm $(sudo docker ps -a -q)

# 플랫폼 에뮬레이션으로 실행 시도
sudo docker run --platform=linux/amd64 -d -p 8000:8000 ai-test:latest
```

### 5. 웹 애플리케이션 접근 테스트

```bash
# 로컬 서비스 연결 테스트
curl -I http://localhost:8000

# Cloudflare 터널을 통한 도메인 접속 테스트
curl -I https://ai.mydairy.my
```

### 6. 메타데이터로 스크립트 완료 확인

```bash
# 인스턴스 내부에서 확인
curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/guest-attributes/startup-script/status
```

결과가 `DONE`이면 스크립트가 성공적으로 완료된 것입니다.

### 7. GPU 상태 확인

```bash
# NVIDIA GPU 상태 확인
nvidia-smi

# GPU 컨테이너 연결 테스트
sudo docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi
```

### 8. 주요 문제 해결 가이드

#### 문제 1: Docker 컨테이너가 실행되지 않거나 바로 종료됨

로그 확인:
```bash
sudo docker ps -a  # 상태 확인
sudo docker logs $(sudo docker ps -a -q | head -1)  # 로그 확인
```

가능한 원인과 해결 방법:

1. **플랫폼 불일치**: 다음 오류가 나타날 경우 - `platform linux/arm64 does not match the detected host platform linux/amd64`
   ```bash
   # 호환 모드로 실행
   sudo docker run --platform=linux/amd64 -d -p 8000:8000 ai-test:latest
   ```

2. **이미지 문제**: 이미지가 제대로 로드되지 않았을 경우
   ```bash
   # 다시 이미지 로드
   sudo docker load < /opt/ai-app/ai-test.tar
   ```

3. **포트 충돌**: 포트가 이미 사용 중인 경우
   ```bash
   # 포트 사용 확인
   sudo netstat -tlnp | grep 8000
   # 다른 포트로 시도
   sudo docker run -d -p 8001:8000 ai-test:latest
   ```

#### 문제 2: cloudflared 서비스 문제

오류 확인:
```bash
sudo systemctl status cloudflared
sudo journalctl -u cloudflared
```

해결 방법:
```bash
# 서비스 재시작
sudo systemctl restart cloudflared

# 인증 파일 확인
sudo ls -la /etc/cloudflared/
```

#### 문제 3: 스타트업 스크립트가 완료되지 않음

1. 로그 확인:
   ```bash
   sudo tail -f /var/log/startup-script.log
   ```

2. 수동 실행:
   ```bash
   sudo bash /var/run/google.startup.script
   ```

### 9. 테스트 체크리스트

| 항목 | 명령어 | 정상 출력 예시 |
|------|--------|--------------|
| 인스턴스 상태 | `gcloud compute instances list` | test-gpu-spot RUNNING |
| SSH 연결 | `gcloud compute ssh test-gpu-spot --zone=asia-east1-a` | 연결 성공 |
| 스크립트 완료 | `curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/guest-attributes/startup-script/status` | DONE |
| cloudflared 서비스 | `sudo systemctl status cloudflared` | active (running) |
| Docker 실행 | `sudo docker ps` | CONTAINER ID IMAGE PORTS NAMES... |
| 웹 접속 | `curl -I http://localhost:8000` | HTTP/1.1 200 OK |
| Cloudflare 연결 | `curl -I https://ai.mydairy.my` | HTTP/1.1 200 OK |
| GPU 상태 | `nvidia-smi` | NVIDIA-SMI 출력 있음 |
