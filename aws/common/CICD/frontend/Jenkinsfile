pipeline {
  agent any

  environment {
    PROJECT_NAME     = "pumati"                       // 프로젝트명
    SERVICE_NAME     = "frontend"                     // 서비스명
    S3_BUCKET        = "s3-pumati-common-storage"     // S3 버킷
    AWS_REGION       = "ap-northeast-2"               // 리전
    AWS_ACCOUNT_ID   = "236450698266"                 // 계정 ID
  }

  stages {
    stage('Set Branch & Cron Trigger') {
      steps {
        echo """
        ============================================
        스테이지 시작: Set Branch & Cron Trigger
        ============================================
        """
        script {
          // 브랜치명 추출 및 환경 설정
          env.BRANCH = (env.BRANCH_NAME ?: env.GIT_BRANCH)?.replaceFirst(/^origin\//, '') ?: 'unknown'

          if (env.BRANCH == 'main') {
            // prod는 매일 9시에 자동 실행
            properties([pipelineTriggers([cron('0 9 * * *')])])  

          // } else if (env.BRANCH == 'dev') {
          //   properties([pipelineTriggers([])])

          } else {
            properties([pipelineTriggers([])])  // 트리거 초기화
            echo "지원되지 않는 브랜치입니다: ${env.BRANCH}. 빌드를 중단합니다."
            currentBuild.result = 'NOT_BUILT'
            error("Unsupported branch: ${env.BRANCH}")
          }

          // 설정 확인 로그
          echo "현재 브랜치: ${env.BRANCH}"
        }
      }
    }

    stage('Notify Before Start') {
      when {
          expression { env.BRANCH in ['main', 'dev'] }
      }
      steps {
        echo """
        ============================================
        스테이지 시작: Notify Before Start
        ============================================
        """
        script {
          try {
            // Jenkins의 Credentials에서 'Discord-Webhook' ID를 사용하여 웹훅 URL을 가져옴
            withCredentials([string(credentialsId: 'Discord-Webhook', variable: 'DISCORD')]) {
              discordSend(
                description: "빌드가 곧 시작됩니다: ${env.SERVICE_NAME} - ${env.BRANCH} 브랜치",
                link: env.BUILD_URL,
                title: "빌드 시작",
                webhookURL: DISCORD
              )
            }
          } catch (e) {
            echo "디스코드 알림 전송 실패: ${e.message}"
          }
        }
      }
    }

    stage('Checkout') {
      steps {
        echo """
        ============================================
        스테이지 시작: Checkout
        ============================================
        """
        checkout scm
      }
    }

    stage('Set Environment by Branch') {
      steps {
        echo """
        ============================================
        스테이지 시작: Set Environment by Branch
        ============================================
        """
        script {
          // 타임스탬프 + 커밋 해시 생성
          def timestamp = new Date().format("yyyyMMdd-HHmmss", TimeZone.getTimeZone('Asia/Seoul'))
          def shortHash = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()

          if (env.BRANCH == 'main') {
            env.ENV_LABEL = 'prod'
            env.FE_PRIVATE_IP = '10.3.0.228'

          // } else {
          //   env.ENV_LABEL = 'dev'
          //   env.FE_PRIVATE_IP = '10.1.0.253'
          }

          env.ECR_REPO  = "${env.PROJECT_NAME}-${env.ENV_LABEL}-${env.SERVICE_NAME}-ecr"
          env.IMAGE_TAG = "${env.SERVICE_NAME}-${env.ENV_LABEL}-${env.BUILD_NUMBER}-${timestamp}-${shortHash}"
          env.ECR_IMAGE = "${env.AWS_ACCOUNT_ID}.dkr.ecr.${env.AWS_REGION}.amazonaws.com/${env.ECR_REPO}:${env.IMAGE_TAG}"

          echo "환경 설정 완료"
          echo "IMAGE_TAG: ${env.IMAGE_TAG}"
          echo "ECR_IMAGE: ${env.ECR_IMAGE}"
        }
      }
    }

    stage('Fetch .env from AWS Secrets Manager') {
      steps {
        echo """
        ============================================
        스테이지 시작: Fetch .env from AWS Secrets Manager
        ============================================
        """
        script {
          try {
            // 1. Secrets Manager에서 .env 내용 가져오기
            def secret = sh(
              script: """
                set -e
                aws secretsmanager get-secret-value \
                  --secret-id ${env.PROJECT_NAME}-${env.ENV_LABEL}-${env.SERVICE_NAME}-.env \
                  --region ${env.AWS_REGION} \
                  --query SecretString \
                  --output text
              """,
              returnStdout: true
            ).trim()

            // 2. .env 파일로 저장
            writeFile file: '.env', text: secret

            // 3. 보안 강화를 위한 퍼미션 제한
            sh 'chmod 600 .env'

            echo ".env 파일 로딩 완료"
          } catch (e) {
            echo ".env 시크릿 로딩 실패: ${e.message}"
            currentBuild.result = 'FAILURE'
            error("빌드 중단: Secrets Manager에서 .env를 불러올 수 없습니다.")
          }
        }
      }
    }

    // .env 파일 내용 확인 
    // stage('Check .env content') {
    //   steps {
    //     script {
    //       echo ".env 파일 내용 확인 시작"
    //       sh 'cat .env'
    //     }
    //   }
    // }

    stage('Authorize Docker to ECR') {
      steps {
        echo """
        ============================================
        스테이지 시작: Authorize Docker to ECR
        ============================================
        """
        script {
          sh """
            set -e
            aws ecr get-login-password --region ${env.AWS_REGION} | \
            docker login --username AWS --password-stdin ${env.AWS_ACCOUNT_ID}.dkr.ecr.${env.AWS_REGION}.amazonaws.com
          """
          echo "ECR 인증 완료"
        }
      }
    }

    stage('Docker Build & Push to ECR') {
      steps {
        echo """
        ============================================
        스테이지 시작: Docker Build & Push to ECR
        ============================================
        """
        script {
          sh """
            # .env 파일에서 필요한 값 추출
            set -e
            export \$(cat .env | grep NEXT_PUBLIC_BASE_URL)
            export \$(cat .env | grep NEXT_PUBLIC_API_BASE_URL)
            export \$(cat .env | grep NEXT_PUBLIC_S3_HOSTNAME)
            export \$(cat .env | grep NEXT_PUBLIC_KATEBOO_CODE)

            # Docker 빌드
            docker build \\
              --build-arg NEXT_PUBLIC_BASE_URL=\$NEXT_PUBLIC_BASE_URL \\
              --build-arg NEXT_PUBLIC_API_BASE_URL=\$NEXT_PUBLIC_API_BASE_URL \\
              --build-arg NEXT_PUBLIC_S3_HOSTNAME=\$NEXT_PUBLIC_S3_HOSTNAME \\
              --build-arg NEXT_PUBLIC_KATEBOO_CODE=\$NEXT_PUBLIC_KATEBOO_CODE \\
              -t ${env.ECR_IMAGE} .

            docker push ${env.ECR_IMAGE}
          """
          echo "Docker 이미지 빌드 및 ECR 푸시 완료"
        }
      }
    }

    stage('Save Docker Image & Upload to S3') {
      steps {
        echo """
        ============================================
        스테이지 시작: Save Docker Image & Upload to S3
        ============================================
        """
        script {
          def tarFile = "${env.IMAGE_TAG}.tar"
          def gzipFile = "${tarFile}.gz"

          sh """
            echo "Docker 이미지 저장: ${tarFile}"
            docker save -o ${tarFile} ${env.ECR_IMAGE}

            echo "압축 중: ${gzipFile}"
            gzip -c ${tarFile} > ${gzipFile}

            echo "S3에 업로드 중..."
            aws s3 cp ${gzipFile} s3://${env.S3_BUCKET}/CI/${env.ENV_LABEL}/${env.SERVICE_NAME}/${gzipFile} --region ${env.AWS_REGION}

            echo "로컬 파일 정리"
            rm -f ${tarFile} ${gzipFile}

            echo "S3 업로드 완료"
          """
        }
      }
    }

    stage('Deploy to Frontend EC2 via SSH') {
      steps {
        echo """
        ============================================
        스테이지 시작: Deploy to Frontend EC2 via SSH
        ============================================
        """
        script {
          echo "EC2에 SSH 접속하여 프론트엔드 자동 배포 시작..."

          withCredentials([
            sshUserPrivateKey(credentialsId: 'PUMATI_FULL_MASTER', keyFileVariable: 'KEY_FILE', usernameVariable: 'SSH_USER')
          ]) {
            sh """
ssh -o StrictHostKeyChecking=no -i \$KEY_FILE \$SSH_USER@${env.FE_PRIVATE_IP} << 'EOF'
  set -e

  echo "기존 컨테이너 중지 및 제거"
  CONTAINER_ID=\$(docker ps -aqf "name=^/${env.SERVICE_NAME}\$")

  if [ -n "\$CONTAINER_ID" ]; then
    echo "컨테이너 존재함. 중지 및 삭제: \$CONTAINER_ID"
    docker stop \$CONTAINER_ID || true
    docker rm \$CONTAINER_ID || true
  else
    echo "삭제할 기존 컨테이너 없음"
  fi

  echo "ECR 인증"
  aws ecr get-login-password --region ${env.AWS_REGION} | \\
    docker login --username AWS --password-stdin ${env.AWS_ACCOUNT_ID}.dkr.ecr.${env.AWS_REGION}.amazonaws.com

  echo "ECR 이미지 Pull: ${env.ECR_IMAGE}"
  docker pull ${env.ECR_IMAGE}

  echo "새 컨테이너 실행"
  docker run -d --name ${env.SERVICE_NAME} -p 3000:3000 ${env.ECR_IMAGE}

  echo "사용하지 않는 이미지 정리"
  docker image prune -a -f

  echo "배포 완료"
EOF
        """
          }
        }
      }
    }
  }

  post {
    success {
      script {
        if (env.BRANCH == 'main') {  // dev 브랜치 조건 제거
          withCredentials([string(credentialsId: 'Discord-Webhook', variable: 'DISCORD')]) {
            discordSend(
              description: """
              제목 : ${currentBuild.displayName}
              결과 : 성공
              베포 이미지 태그 : ${env.IMAGE_TAG}
              실행 시간 : ${currentBuild.duration / 1000}s
              """.stripIndent(),
              link: env.BUILD_URL,
              title: "${env.JOB_NAME} :: ${env.BRANCH} :: 배포 성공",
              result: 'SUCCESS',
              webhookURL: DISCORD
            )
          }
        }
      }
    }

    failure {
      script {
        if (env.BRANCH == 'main') {  // dev 브랜치 조건 제거
          withCredentials([string(credentialsId: 'Discord-Webhook', variable: 'DISCORD')]) {
            discordSend(
              description: """
              제목 : ${currentBuild.displayName}
              결과 : 실패
              배포 이미지 태그 : ${env.IMAGE_TAG}
              실행 시간 : ${currentBuild.duration / 1000}s
              """.stripIndent(),
              link: env.BUILD_URL,
              title: "${env.JOB_NAME} :: ${env.BRANCH} :: 배포 실패",
              result: 'FAILURE',
              webhookURL: DISCORD
            )
          }
        }
      }
    }
  }
}
