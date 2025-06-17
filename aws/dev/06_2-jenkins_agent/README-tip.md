# 🤖 Jenkins 에이전트 (06_2-jenkins_agent)

Jenkins UI에서 생성한 노드와 **정확히 일치하는 JNLP 에이전트**를 Kubernetes에 배포합니다.

## 📋 목차

- [🎯 개요](#-개요)
- [🏗️ 아키텍처](#️-아키텍처)
- [📦 구성 요소](#-구성-요소)
- [🚀 배포 순서](#-배포-순서)
- [🔧 설정 방법](#-설정-방법)
- [🔍 모니터링](#-모니터링)
- [🐛 트러블슈팅](#-트러블슈팅)

## 🎯 개요

### ✅ 주요 특징
- **JNLP 연결**: Jenkins UI에서 제공한 정확한 연결 방법 사용
- **WebSocket 지원**: 기본 WebSocket 연결 (TCP로 변경 가능)
- **ECR 통합**: Kaniko 사이드카로 Docker 이미지 빌드/푸시
- **완전 호환**: Jenkins UI 설정과 100% 호환
- **라벨 매칭**: Jenkins UI의 "static" 라벨과 일치

### 🔄 Jenkins 연결 방식
```
Jenkins UI에서 제공된 명령어:
java -jar agent.jar -url http://jenkins.jenkins.svc.cluster.local:8080/ 
  -secret 526600b00d1eb4754ddca64f5d3c65d8ecc346c949aa2972d73b055525c2410a 
  -name agent -webSocket -workDir "/home/jenkins"
```

### 🔄 Jenkins 마스터와의 관계
```
┌─────────────────┐    JNLP     ┌─────────────────┐
│  Jenkins 마스터  │ ←────────→  │ Jenkins 에이전트 │
│   (06-ci)      │   :50000    │  (06-2-agent)  │
│                │             │                │
│ • 작업 관리     │             │ • 빌드 실행     │
│ • 스케줄링     │             │ • 이미지 빌드   │
│ • UI 제공      │             │ • ECR 푸시      │
└─────────────────┘             └─────────────────┘
```

## 🏗️ 아키텍처

### 🔧 컨테이너 구성
```
┌─────────────────────────────────────────┐
│              Agent Pod                  │
├─────────────────────────────────────────┤
│  📦 jenkins-agent 컨테이너              │
│  • JNLP 클라이언트                      │
│  • 빌드 도구 및 환경                    │
│  • Jenkins 마스터와 통신                │
├─────────────────────────────────────────┤
│  🐳 kaniko 사이드카 컨테이너            │
│  • Docker 이미지 빌드                   │
│  • ECR에 이미지 푸시                    │
│  • credential helper 사용               │
└─────────────────────────────────────────┘
```

### 🔐 권한 구조
```
┌──────────────────┐
│   IAM 역할       │
│ jenkins-agent-   │
│    ecr-role      │
└──────────────────┘
         │
         ▼
┌──────────────────┐    연결    ┌──────────────────┐
│  ServiceAccount  │ ────────→  │   ECR 권한       │
│  jenkins-agent   │            │ • 로그인         │
└──────────────────┘            │ • 이미지 푸시    │
                                │ • 저장소 관리    │
                                └──────────────────┘
```

## 📦 구성 요소

### 🔑 주요 리소스

| 리소스 타입 | 이름 | 용도 |
|------------|------|------|
| **Deployment** | `jenkins-agent` | 에이전트 Pod 관리 |
| **Service** | `jenkins-agent` | JNLP 통신 (포트 50000) |
| **ServiceAccount** | `jenkins-agent` | ECR 권한 연결 |
| **Secret** | `jenkins-agent-secret` | 마스터 연결 키 |
| **Secret** | `kaniko-ecr-config` | ECR 인증 설정 |
| **IAM Role** | `jenkins-agent-ecr-role` | ECR 접근 권한 |

### 🐳 컨테이너 이미지

| 컨테이너 | 이미지 | 용도 |
|---------|--------|------|
| **jenkins-agent** | `jenkins/inbound-agent:latest` | JNLP 에이전트 및 빌드 작업 |
| **git** | `alpine/git:latest` | GitHub/GitLab 소스코드 클론 |
| **aws-cli** | `amazon/aws-cli:latest` | AWS 서비스 접근 (Secrets Manager 등) |
| **kaniko** | `gcr.io/kaniko-project/executor:debug` | Docker 이미지 빌드 및 ECR 푸시 |

## 🚀 배포 순서

### 1️⃣ **전제 조건 확인**
```bash
# Jenkins 마스터가 Running 상태인지 확인
kubectl get pods -n jenkins

# Jenkins UI 접속 가능한지 확인
curl -I https://jenkins.your-domain.com/login
```

### 2️⃣ **Jenkins UI에서 노드 생성** ✅
이미 완료되었습니다:
- **노드명**: `agent`
- **라벨**: `static`
- **작업 디렉토리**: `/home/jenkins`
- **연결 방법**: `Launch agent by connecting it to the master`

### 3️⃣ **Secret 키 확인** ✅
Jenkins UI에서 제공된 Secret 키:
```
526600b00d1eb4754ddca64f5d3c65d8ecc346c949aa2972d73b055525c2410a
```

### 4️⃣ **설정 파일 확인** ✅
`secrets.auto.tfvars` 파일이 이미 생성되어 있습니다.

### 5️⃣ **Terraform 배포**
```bash
# 06_2-jenkins_agent 디렉토리로 이동
cd aws/dev/06_2-jenkins_agent

# 초기화
terraform init

# 계획 확인
terraform plan

# 배포 실행
terraform apply
```

## 🔧 설정 방법

### 📝 terraform.tfvars 예시
```hcl
# Jenkins 에이전트 Secret (Jenkins UI에서 복사)
jenkins_agent_secret = "526600b00d1eb4754ddca64f5d3c65d8ecc346c949aa2972d73b055525c2410a"

# 에이전트 설정
jenkins_agent_name     = "k8s-agent-1"
jenkins_agent_replicas = 1

# 리소스 설정 (필요시 조정)
jenkins_agent_resources = {
  requests = {
    cpu    = "1000m"  # 1 CPU
    memory = "2Gi"    # 2GB RAM
  }
  limits = {
    cpu    = "4000m"  # 4 CPU
    memory = "8Gi"    # 8GB RAM
  }
}

# Kaniko 리소스 설정
kaniko_resources = {
  requests = {
    cpu    = "500m"   # 0.5 CPU
    memory = "1Gi"    # 1GB RAM
  }
  limits = {
    cpu    = "2000m"  # 2 CPU
    memory = "4Gi"    # 4GB RAM
  }
}
```

### 🔄 에이전트 개수 조정
```bash
# 에이전트 개수 변경
terraform apply -var="jenkins_agent_replicas=2"
```

## 🔍 모니터링

### 📊 Pod 상태 확인
```bash
# 에이전트 Pod 상태
kubectl get pods -n jenkins -l app.kubernetes.io/component=agent

# 상세 정보
kubectl describe pod -n jenkins -l app.kubernetes.io/component=agent

# 로그 확인
kubectl logs -n jenkins -l app.kubernetes.io/component=agent -c jenkins-agent
kubectl logs -n jenkins -l app.kubernetes.io/component=agent -c kaniko
```

### 🔗 연결 상태 확인
```bash
# Jenkins 마스터에서 에이전트 연결 확인
# Jenkins UI → Jenkins 관리 → 노드 관리
```

### 📈 리소스 사용량
```bash
# CPU/메모리 사용량
kubectl top pods -n jenkins -l app.kubernetes.io/component=agent

# 노드 배치 확인
kubectl get pods -n jenkins -o wide -l app.kubernetes.io/component=agent
```

## 🐛 트러블슈팅

### ❌ 일반적인 문제들

#### 1. 에이전트가 마스터에 연결되지 않음
```bash
# Secret 키 확인
kubectl get secret jenkins-agent-secret -n jenkins -o yaml

# 환경 변수 확인
kubectl describe pod -n jenkins -l app.kubernetes.io/component=agent

# 해결책: Jenkins UI에서 새로운 Secret 키 생성 후 업데이트
```

#### 2. ECR 이미지 푸시 실패
```bash
# IAM 역할 확인
aws sts assume-role --role-arn $(terraform output -raw ecr_access_info | jq -r .iam_role_arn) --role-session-name test

# Kaniko 설정 확인
kubectl get secret kaniko-ecr-config -n jenkins -o yaml

# 해결책: IAM 정책 권한 확인 및 ECR 저장소 존재 여부 확인
```

#### 3. Pod가 Pending 상태
```bash
# 노드 리소스 확인
kubectl describe nodes

# PVC 상태 확인
kubectl get pvc -n jenkins

# 해결책: 노드 스케일링 또는 리소스 요청량 조정
```

#### 4. Kaniko 컨테이너 오류
```bash
# Kaniko 로그 확인
kubectl logs -n jenkins -l app.kubernetes.io/component=agent -c kaniko

# ECR 인증 테스트
kubectl exec -it -n jenkins $(kubectl get pods -n jenkins -l app.kubernetes.io/component=agent -o name | head -1) -c kaniko -- cat /kaniko/.docker/config.json

# 해결책: ECR credential helper 설정 확인
```

### 🔧 유용한 명령어

```bash
# 에이전트 Pod 재시작
kubectl rollout restart deployment/jenkins-agent -n jenkins

# Secret 업데이트
kubectl patch secret jenkins-agent-secret -n jenkins --type='json' -p='[{"op": "replace", "path": "/data/secret", "value": "NEW_SECRET_BASE64_ENCODED"}]'

# 리소스 사용량 모니터링
watch kubectl top pods -n jenkins -l app.kubernetes.io/component=agent

# 네트워크 연결 테스트
kubectl exec -it -n jenkins $(kubectl get pods -n jenkins -l app.kubernetes.io/component=agent -o name | head -1) -c jenkins-agent -- curl http://jenkins.jenkins.svc.cluster.local:8080
```

### 📞 지원

문제가 지속되면 다음을 확인하세요:

1. **Jenkins 마스터 상태**: 06-ci 모듈의 Jenkins 마스터가 정상 동작하는지 확인
2. **네트워크 연결**: 에이전트와 마스터 간 네트워크 통신 상태
3. **IAM 권한**: ECR 접근을 위한 IAM 역할 및 정책 설정
4. **리소스 할당**: CPU/메모리 요청량이 노드 용량을 초과하지 않는지 확인

---

## 💼 Jenkins Pipeline 사용 예제

### 🔥 **완전한 CI/CD Pipeline 예제**

```groovy
pipeline {
    agent {
        label 'static'  // 우리가 설정한 라벨
    }
    
    environment {
        // ECR 정보
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-2.amazonaws.com"
        ECR_REPOSITORY = "my-app"
        IMAGE_TAG = "${BUILD_NUMBER}-${GIT_COMMIT[0..7]}"
        
        // AWS 리전
        AWS_REGION = "ap-northeast-2"
    }
    
    stages {
        stage('📥 Source Checkout') {
            steps {
                container('git') {
                    script {
                        // GitHub에서 소스코드 클론
                        sh '''
                            echo "=== GitHub에서 소스코드 클론 ==="
                            git clone https://github.com/your-org/your-repo.git .
                            git checkout ${BRANCH_NAME}
                            ls -la
                        '''
                    }
                }
            }
        }
        
        stage('🔐 GitHub Token 설정') {
            steps {
                container('aws-cli') {
                    script {
                        // Secrets Manager에서 GitHub 토큰 가져오기
                        sh '''
                            echo "=== GitHub 토큰 가져오기 ==="
                            GITHUB_TOKEN=$(aws secretsmanager get-secret-value \
                                --secret-id github/access-token \
                                --query SecretString --output text)
                            
                            # Git 인증 설정
                            git config --global credential.helper store
                            echo "https://oauth2:${GITHUB_TOKEN}@github.com" > ~/.git-credentials
                        '''
                    }
                }
            }
        }
        
        stage('🏗️ Build Application') {
            steps {
                container('jenkins-agent') {
                    script {
                        // 애플리케이션 빌드 (예: Node.js)
                        sh '''
                            echo "=== 애플리케이션 빌드 시작 ==="
                            
                            # Node.js 빌드 예제
                            if [ -f "package.json" ]; then
                                echo "Node.js 애플리케이션 감지"
                                npm ci
                                npm run build
                                npm test
                            fi
                            
                            # Java 빌드 예제
                            if [ -f "pom.xml" ]; then
                                echo "Maven 프로젝트 감지"
                                mvn clean package
                            fi
                            
                            # Python 빌드 예제
                            if [ -f "requirements.txt" ]; then
                                echo "Python 애플리케이션 감지"
                                pip install -r requirements.txt
                                python -m pytest
                            fi
                            
                            echo "빌드 완료!"
                        '''
                    }
                }
            }
        }
        
        stage('🐳 Docker 이미지 빌드 & ECR 푸시') {
            steps {
                container('kaniko') {
                    script {
                        // Kaniko로 Docker 이미지 빌드 및 ECR 푸시
                        sh '''
                            echo "=== Docker 이미지 빌드 및 ECR 푸시 ==="
                            
                            # Dockerfile 존재 확인
                            if [ ! -f "Dockerfile" ]; then
                                echo "Dockerfile이 없습니다!"
                                exit 1
                            fi
                            
                            # Kaniko로 이미지 빌드 및 푸시
                            /kaniko/executor \
                                --context /workspace \
                                --dockerfile /workspace/Dockerfile \
                                --destination ${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG} \
                                --destination ${ECR_REGISTRY}/${ECR_REPOSITORY}:latest \
                                --cache=true \
                                --cleanup
                            
                            echo "이미지 푸시 완료: ${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"
                        '''
                    }
                }
            }
        }
        
        stage('🚀 ArgoCD 배포 트리거') {
            steps {
                container('git') {
                    script {
                        // GitOps 저장소 업데이트
                        sh '''
                            echo "=== GitOps 저장소 업데이트 ==="
                            
                            # GitOps 저장소 클론
                            git clone https://github.com/your-org/gitops-repo.git gitops
                            cd gitops
                            
                            # Helm values 파일 업데이트
                            sed -i "s|image:.*|image: ${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}|g" \
                                environments/dev/values.yaml
                            
                            # 변경사항 커밋 및 푸시
                            git config user.name "Jenkins Agent"
                            git config user.email "jenkins@your-domain.com"
                            git add .
                            git commit -m "🚀 Deploy ${ECR_REPOSITORY}:${IMAGE_TAG} to dev"
                            git push origin main
                            
                            echo "GitOps 저장소 업데이트 완료!"
                        '''
                    }
                }
            }
        }
        
        stage('📧 알림') {
            steps {
                container('aws-cli') {
                    script {
                        // SNS로 배포 완료 알림
                        sh '''
                            echo "=== 배포 완료 알림 ==="
                            
                            aws sns publish \
                                --topic-arn "arn:aws:sns:ap-northeast-2:${AWS_ACCOUNT_ID}:jenkins-notifications" \
                                --message "✅ 배포 완료: ${ECR_REPOSITORY}:${IMAGE_TAG}" \
                                --subject "Jenkins Build #${BUILD_NUMBER} 성공"
                        '''
                    }
                }
            }
        }
    }
    
    post {
        always {
            // 작업 공간 정리
            cleanWs()
        }
        
        failure {
            container('aws-cli') {
                script {
                    // 실패 알림
                    sh '''
                        aws sns publish \
                            --topic-arn "arn:aws:sns:ap-northeast-2:${AWS_ACCOUNT_ID}:jenkins-notifications" \
                            --message "❌ 빌드 실패: ${ECR_REPOSITORY} Build #${BUILD_NUMBER}" \
                            --subject "Jenkins Build #${BUILD_NUMBER} 실패"
                    '''
                }
            }
        }
        
        success {
            echo "🎉 빌드 및 배포가 성공적으로 완료되었습니다!"
        }
    }
}
```

### 🔧 **컨테이너별 사용법**

| 컨테이너 | 사용 방법 | 예시 |
|---------|-----------|------|
| **git** | 소스코드 클론, Git 작업 | `container('git') { sh 'git clone ...' }` |
| **aws-cli** | AWS 서비스 접근 | `container('aws-cli') { sh 'aws secretsmanager ...' }` |
| **kaniko** | Docker 이미지 빌드 | `container('kaniko') { sh '/kaniko/executor ...' }` |
| **jenkins-agent** | 일반 빌드 작업 | `container('jenkins-agent') { sh 'npm run build' }` |

### 🚀 **간단한 빌드 Pipeline**

```groovy
pipeline {
    agent { label 'static' }
    
    stages {
        stage('Clone') {
            steps {
                container('git') {
                    git 'https://github.com/your-org/your-repo.git'
                }
            }
        }
        
        stage('Build & Push') {
            steps {
                container('kaniko') {
                    sh '''
                        /kaniko/executor \
                            --context . \
                            --dockerfile Dockerfile \
                            --destination ${ECR_REGISTRY}/my-app:${BUILD_NUMBER}
                    '''
                }
            }
        }
    }
}
```

## 📚 관련 문서

- [Jenkins 공식 문서](https://www.jenkins.io/doc/)
- [Kaniko 사용법](https://github.com/GoogleContainerTools/kaniko)
- [AWS ECR 가이드](https://docs.aws.amazon.com/ecr/)
- [EKS IAM 역할 매핑](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [Jenkins Pipeline 문법](https://www.jenkins.io/doc/book/pipeline/syntax/) 