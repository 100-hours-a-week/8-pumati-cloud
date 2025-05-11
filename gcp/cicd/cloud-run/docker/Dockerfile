FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

# 시스템 패키지 설치
RUN apt-get update && apt-get install -y \
    git curl wget unzip jq \
    python3 python3-pip python-is-python3 \
    libglib2.0-0 libsm6 libxext6 libxrender-dev \
    libicu-dev ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Python 패키지 설치
RUN pip install --upgrade pip && pip install \
    torch==2.1.0 \
    torchvision==0.16.0 \
    transformers==4.51.3 \
    safetensors \
    fastapi \
    uvicorn==0.29.0 \
    huggingface-hub \
    python-dotenv \
    "numpy<2" \
    sentencepiece \
    "accelerate>=0.20.3" \
    "bitsandbytes>=0.41.0" \
    llama-cpp-python \
    langchain \
    faker

# Runner 설치 디렉토리
WORKDIR /home/github/actions-runner

# 사용자 생성 및 디렉토리 권한
RUN useradd -m github && chown -R github:github /home/github

# ENV (토큰은 빌드 타임에만 유효함)
ENV RUNNER_VERSION=2.323.0
ENV REPO_URL=https://github.com/100-hours-a-week/8-pumati-ai
ENV RUNNER_TOKEN=

# Runner 다운로드 및 검증
RUN curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz \
      -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz && \
    echo "0dbc9bf5a58620fc52cb6cc0448abcca964a8d74b5f39773b7afcad9ab691e19  actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" | shasum -a 256 -c && \
    tar xzf actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz && \
    chown -R github:github .

# 권한 전환
USER github

# config 실행 (딱 한 번, 빌드 타임에만)
RUN ./config.sh --url ${REPO_URL} --token ${RUNNER_TOKEN} --unattended --name cloudrun-runner

# 실행 명령
CMD ["./run.sh"]
