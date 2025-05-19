새 구글 계정 생성 시 해야 할 일

- 프로바이더 설정(terraform-key.json 파일 생성)


시작 전에 해야 할 일

키생성( 이 폼은 전체 리드미에 있음)

# 프로젝트 설정
gcloud config set project ambient-topic-459110-e6

# 서비스 계정 생성 (Terraform 용)
gcloud iam service-accounts create terraform \
  --description="Terraform 관리용 서비스 계정" \
  --display-name="Terraform Service Account"

# 서비스 계정에 소유자 역할 부여
gcloud projects add-iam-policy-binding ambient-topic-459110-e6 \
  --member="serviceAccount:terraform@ambient-topic-459110-e6.iam.gserviceaccount.com" \
  --role="roles/owner"

# 서비스 계정 키 생성 및 저장
gcloud iam service-accounts keys create ~/terraform-key-dev.json \
  --iam-account="terraform@ambient-topic-459110-e6.iam.gserviceaccount.com"

# 클라우드플레어 설정
json과 pem 


1. 구글 로그인
qkrdufdl3580@gmail.com  /  fhdks$2! 로 구글 로그인


brew install —cask google-cloud-sdk
gcloud auth login
# 1. Docker 인증 설정
gcloud auth configure-docker asia-southeast1-docker.pkg.dev

# 2. 이미지 태깅
docker tag my-api-cpu asia-southeast1-docker.pkg.dev/ktb8team-458916/ktb8team-test/my-api-cpu

# 3. 이미지 푸시
docker push asia-southeast1-docker.pkg.dev/ktb8team-458916/ktb8team-test/my-api-cpu
