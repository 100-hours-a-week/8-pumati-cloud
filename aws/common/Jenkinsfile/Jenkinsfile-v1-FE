pipeline {
  agent any

  environment {
    PROJECT_NAME     = "pumati"                       // 프로젝트명
    ENV_LABEL        = ""                             // dev / prod (브랜치에 따라 설정됨)
    SERVICE_NAME     = "frontend"                     // 서비스명
    BUILD_FILE       = ""                             // S3에 업로드할 zip 파일 이름
    S3_BUCKET        = "s3-pumati-common-storage"     // S3 버킷
    AWS_REGION       = "ap-northeast-2"
  }

  stages {
    stage('Set Branch & Environment') {
      steps {
        script {
          // Git 브랜치명 가져오기 (origin/ 접두사 제거)
          def branchName = (env.BRANCH_NAME ?: env.GIT_BRANCH)?.replaceFirst(/^origin\//, '') ?: 'unknown'
          env.BRANCH = branchName
          echo "현재 브랜치: ${branchName}"

          if (branchName == 'main') {
            env.ENV_LABEL = 'prod'   // main → prod
            // 매일 09:00~20:00 매시 정각 실행 (분산형)
            properties([pipelineTriggers([
              cron('0 9 * * *')
            ])])
          } else if (branchName == 'dev') {
            env.ENV_LABEL = 'dev'    // dev → dev
            properties([]) 
            echo "dev 브랜치는 수동 또는 웹훅으로만 트리거됩니다."
          } else {
            properties([pipelineTriggers([])])
            echo "❌ 지원되지 않는 브랜치입니다: ${branchName}. 빌드를 중단합니다."
            currentBuild.result = 'NOT_BUILT'
            error("Unsupported branch: ${branchName}")
          }
        }
      }
    }

    stage('Notify Before Start') {
      when {
          expression { env.BRANCH in ['main', 'dev'] }
      }
      steps {
        script {
          def service = env.SERVICE_NAME ?: '알 수 없는 서비스'
          try {
            withCredentials([string(credentialsId: 'Discord-Webhook', variable: 'DISCORD')]) {
              discordSend(
                description: "🚀 배포가 곧 시작됩니다: ${service} - ${env.BRANCH} 브랜치",
                link: env.BUILD_URL,
                title: "배포 시작",
                webhookURL: "$DISCORD"
              )
            }
          } catch (e) {
            echo "⚠️ 디스코드 알림 전송 실패: ${e.message}"
          }
        }
      }
    }

    stage('Checkout') {
      steps {
        checkout scm
      }
    }
    
    stage('Install Dependencies') {
      steps {
        sh '''
          echo "Installing dependencies using pre-installed pnpm..."
          pnpm install
        '''
      }
    }


    stage('Fetch .env from AWS Secrets Manager') {
      steps {
        script {
          // 1. aws CLI 설치 여부 확인
          sh '''
            if ! command -v aws &> /dev/null; then
              echo "❌ aws CLI not found"
              exit 1
            fi
          '''

          try {
            // 2. Secrets Manager에서 .env 내용 가져오기
            def secret = sh(
              script: """
                aws secretsmanager get-secret-value \
                  --secret-id ${env.PROJECT_NAME}-${env.ENV_LABEL}-${env.SERVICE_NAME}-.env \
                  --region ${env.AWS_REGION} \
                  --query SecretString \
                  --output text
              """,
              returnStdout: true
            ).trim()

            // 3. .env 파일로 저장
            writeFile file: '.env', text: secret

            // 4. 보안 강화를 위한 퍼미션 제한
            sh 'chmod 600 .env'

            echo "✅ .env 파일 로딩 완료"
          } catch (e) {
            echo "⚠️ .env 시크릿 로딩 실패: ${e.message}"
            currentBuild.result = 'FAILURE'
            error("빌드 중단: Secrets Manager에서 .env를 불러올 수 없습니다.")
          }
        }
      }
    }

    stage('Build') {
      steps {
        script {
          echo "pnpm build 시작"
          sh 'pnpm build'
        }
      }
    }


    stage('Archive & Upload to S3') {
      steps {
        script {
          // 1. 타임스탬프 및 커밋 해시로 파일 이름 생성
          def timestamp = new Date().format("yyyyMMdd-HHmmss", TimeZone.getTimeZone('Asia/Seoul'))
          def shortHash = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
          env.BUILD_FILE = "output-${timestamp}-${shortHash}.zip"

          // 2. 압축 + S3 업로드
          echo "📦 압축 대상: .next/, public/, package.json, .env"
          sh """
            zip -r ${env.BUILD_FILE} .next public package.json .env
            echo "✅ 압축 완료: ${env.BUILD_FILE}"

            aws s3 cp ${env.BUILD_FILE} s3://${env.S3_BUCKET}/CI/${env.ENV_LABEL}/${env.SERVICE_NAME}/${env.BUILD_FILE} \
              --region ${env.AWS_REGION}

            echo "✅ S3 업로드 완료: s3://${env.S3_BUCKET}/CI/${env.ENV_LABEL}/${env.SERVICE_NAME}/${env.BUILD_FILE}"
          """
        }
      }
    }
  }

  post {
    success {
      script {
        if (env.BRANCH in ['main', 'dev']) {
          withCredentials([string(credentialsId: 'Discord-Webhook', variable: 'DISCORD')]) {
            discordSend(
              description: """
              📦 **제목:** ${currentBuild.displayName}
              ✅ **결과:** 성공
              ⏱ **실행 시간:** ${currentBuild.duration / 1000}s
              """.stripIndent(),
              link: env.BUILD_URL,
              title: "🎉 ${env.JOB_NAME} :: ${env.BRANCH} :: 빌드 성공",
              result: 'SUCCESS',
              webhookURL: "$DISCORD"
            )
          }
        }
      }
    }

    failure {
      script {
        if (env.BRANCH in ['main', 'dev']) {
          withCredentials([string(credentialsId: 'Discord-Webhook', variable: 'DISCORD')]) {
            discordSend(
              description: """
              📦 **제목:** ${currentBuild.displayName}
              ❌ **결과:** 실패
              ⏱ **실행 시간:** ${currentBuild.duration / 1000}s
              """.stripIndent(),
              link: env.BUILD_URL,
              title: "💥 ${env.JOB_NAME} :: ${env.BRANCH} :: 빌드 실패",
              result: 'FAILURE',
              webhookURL: "$DISCORD"
            )
          }
        }
      }
    }
  }
}
