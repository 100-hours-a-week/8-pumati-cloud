# 1단계: 빌드 스테이지
FROM node:20-alpine AS builder

# 기본 패키지 설치
RUN apk add --no-cache libc6-compat

# 작업 디렉토리 생성
WORKDIR /app

# 패키지 매니저 설치
RUN npm install -g pnpm

# 필수: Next.js 및 TypeScript 환경 구성
COPY package.json pnpm-lock.yaml ./
RUN pnpm install

# next.config.ts를 처리하기 위한 의존성 명시적 설치
RUN pnpm add next@latest typescript ts-node @types/node --save-dev

# 소스 복사 (next.config.ts 포함)
COPY . .

# 환경변수 설정 (빌드 시점)
ARG NEXT_PUBLIC_BASE_URL
ARG NEXT_PUBLIC_API_BASE_URL
ARG NEXT_PUBLIC_S3_HOSTNAME
ARG NEXT_PUBLIC_KATEBOO_CODE

ENV NEXT_PUBLIC_BASE_URL=$NEXT_PUBLIC_BASE_URL
ENV NEXT_PUBLIC_API_BASE_URL=$NEXT_PUBLIC_API_BASE_URL
ENV NEXT_PUBLIC_S3_HOSTNAME=$NEXT_PUBLIC_S3_HOSTNAME
ENV NEXT_PUBLIC_KATEBOO_CODE=$NEXT_PUBLIC_KATEBOO_CODE
ENV NODE_ENV=production

# Next.js 빌드
RUN pnpm build

# 2단계: 실행 스테이지
FROM node:20-alpine AS runner

RUN apk add --no-cache libc6-compat
WORKDIR /app

# 패키지 매니저 설치
RUN npm install -g pnpm

# 의존성 설치 (프로덕션 전용)
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --prod

# 빌드 산출물 복사
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public

# 실행 시 next.config.ts는 필요하지 않음 (런타임에서 사용되지 않음)
# 굳이 복사하려면 아래처럼 유지
COPY --from=builder /app/next.config.ts ./next.config.ts

# 환경변수 설정 (런타임)
ARG NEXT_PUBLIC_BASE_URL
ARG NEXT_PUBLIC_API_BASE_URL
ARG NEXT_PUBLIC_S3_HOSTNAME
ARG NEXT_PUBLIC_KATEBOO_CODE

ENV NEXT_PUBLIC_BASE_URL=$NEXT_PUBLIC_BASE_URL
ENV NEXT_PUBLIC_API_BASE_URL=$NEXT_PUBLIC_API_BASE_URL
ENV NEXT_PUBLIC_S3_HOSTNAME=$NEXT_PUBLIC_S3_HOSTNAME
ENV NEXT_PUBLIC_KATEBOO_CODE=$NEXT_PUBLIC_KATEBOO_CODE
ENV NODE_ENV=production

EXPOSE 3000

# 애플리케이션 실행
CMD ["pnpm", "start"]
