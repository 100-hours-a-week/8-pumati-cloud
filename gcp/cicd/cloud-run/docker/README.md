Dockerfile 실행 방법

# 도커 인증 설정
gcloud auth configure-docker asia-southeast1-docker.pkg.dev


# 프로젝트 아이디 수정 필수
# 리눅스 환경일 경우. 맥은 저 아래꺼
docker build -t asia-southeast1-docker.pkg.dev/ktb8team-458916/ktb8team-docker-repo/pumati-cloud-run:latest .


# 맥에서 빌드시 아키텍처 명시 필수
docker buildx build \
  --platform linux/amd64 \
  -t asia-southeast1-docker.pkg.dev/ktb8team-458916/ktb8team-docker-repo/pumati-cloud-run:latest \
  .

docker push asia-southeast1-docker.pkg.dev/ktb8team-458916/ktb8team-docker-repo/pumati-cloud-run:latest






