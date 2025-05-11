클라우드런 용 gcloud 명령어(GPU 클라우드런은 테라폼 완전 지원 x, 간단함)

# gcloud 로그인
gcloud auth login

# 먼저 클라우드런을 실행하기 위한 API 활성화
gcloud services enable \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  iam.googleapis.com

gcloud services enable run.googleapis.com cloudbuild.googleapis.com

# 업데이트(선택)
gcloud components update

# 아래를 실행
chmod +x gloud-run.sh
./gloud-run.sh


# 클라우드런 콘솔에서 확인
https://console.cloud.google.com/run/detail/asia-southeast1/pumati-cloud-run/logs?project=ktb8team-458916