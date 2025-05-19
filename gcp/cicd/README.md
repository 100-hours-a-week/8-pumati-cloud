# 비키 GPU 할당 안되는 아이디 활용.


프로젝트 아이디 : ktb8team-459100


# 프로젝트 설정
gcloud config set project ktb8team-459100

# 서비스 계정 생성 (Terraform 용)
gcloud iam service-accounts create terraform \
  --description="Terraform 관리용 서비스 계정" \
  --display-name="Terraform Service Account"

# 서비스 계정에 소유자 역할 부여 (모든 리소스 제어 가능)
gcloud projects add-iam-policy-binding ktb8team-459100 \
  --member="serviceAccount:terraform@ktb8team-459100.iam.gserviceaccount.com" \
  --role="roles/owner"

# 서비스 계정 키 생성 (gcp/common/terraform-keys 폴더로 직접 옮길 것)
gcloud iam service-accounts keys create ~/terraform-key-cicd.json \
  --iam-account="terraform@ktb8team-459100.iam.gserviceaccount.com"
