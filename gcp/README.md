새 구글 계정 생성 시 할 일

# 새 계정으로 인증

gcloud auth login

# 프로젝트 선택

# 주의! 프로젝트 이름과 프로젝트 ID 는 다름!!
gcloud config set project [PROJECT_ID]

# 서비스 계정 생성(테라폼 용)

gcloud iam service-accounts create terraform \
  --description="Terraform 관리용 서비스 계정" \
  --display-name="Terraform Service Account"

# 서비스 계정에 소유자 역할 부여 - 모든 리소스 제어 가능
gcloud projects add-iam-policy-binding [PROJECT_ID] \
  --member="serviceAccount:terraform@[PROJECT_ID].iam.gserviceaccount.com" \
  --role="roles/owner"


# 서비스 계정 키 생성. 환경은 알맞게 바꿔서 
# 이 명령어 사용하면 사용자 폴더에 키 파일이 생성됨. 이걸 gcp/common/terraform-keys 폴더에 저장
gcloud iam service-accounts keys create ~/terraform-key-[환경].json \
  --iam-account="terraform@[PROJECT_ID].iam.gserviceaccount.com"



# 인증 확인(선택)
gcloud auth activate-service-account --key-file=~/terraform-key.json
gcloud auth list


이사 절차
prod 
일단 파일 다 복사.


# 클라우드플레어 절차

로컬에서 터널 생성

cloudflared tunnel create [터널명]

ID 나오고 .cloudflared 에 json 자격 증명 파일 생김.
아이디 나오면 이걸로 secret 고치기

DNS 연결(연결 후 대시보드 가서 확인해보셈)

cloudflared tunnel route dns [터널명] [서브도메인명 혹은 도메인명]
cloudflared tunnel route dns ai-tunnel-prod-vicky prod-vicky.mydairy.my