#==============================================================================
# 06-2-agent: Jenkins 에이전트 (빌드 전용) 구성
#==============================================================================

# 🎯 Jenkins 에이전트 구성 목표:
# ✅ Jenkins 마스터가 완전히 준비된 후 별도 배포
# ✅ ECR 이미지 빌드/푸시 권한 (Kaniko 사용)
# ✅ 마스터와 안전한 JNLP 연결
# ✅ 스팟 인스턴스에 배치로 비용 절약
# ✅ 빌드 전용 - 관리 작업 안함

#==============================================================================
# ECR 접근용 IAM 역할 (에이전트용)
#==============================================================================
resource "aws_iam_role" "jenkins_agent_ecr_role" {
  name = "${local.project_name}-${local.environment}-jenkins-agent-ecr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Federated = local.cluster_oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${local.cluster_oidc_issuer_url}:sub" = "system:serviceaccount:${local.jenkins_namespace}:jenkins-agent"
            "${local.cluster_oidc_issuer_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name      = "${local.project_name}-${local.environment}-jenkins-agent-ecr-role"
    Component = "Jenkins-Agent-ECR"
  })
}

# Jenkins 에이전트 종합 권한 정책 (ECR + Secrets Manager + CodeCommit 등)
resource "aws_iam_policy" "jenkins_agent_build_policy" {
  name        = "${local.project_name}-${local.environment}-jenkins-agent-build-policy"
  description = "Jenkins Agent comprehensive build policy for ECR, Secrets, and source control"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # 🔐 ECR 전체 권한 (이미지 빌드 및 푸시)
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",           # ECR 로그인 토큰 가져오기
          "ecr:BatchCheckLayerAvailability",     # 레이어 존재 확인
          "ecr:GetDownloadUrlForLayer",          # 레이어 다운로드 URL
          "ecr:BatchGetImage",                   # 이미지 가져오기
          "ecr:InitiateLayerUpload",             # 레이어 업로드 시작
          "ecr:UploadLayerPart",                 # 레이어 업로드
          "ecr:CompleteLayerUpload",             # 레이어 업로드 완료
          "ecr:PutImage",                        # 이미지 푸시
          "ecr:CreateRepository",                # 저장소 생성 (자동 생성)
          "ecr:DescribeRepositories",            # 저장소 정보 조회
          "ecr:ListImages",                      # 이미지 목록 조회
          "ecr:DescribeImages",                  # 이미지 정보 조회
          "ecr:TagResource",                     # 태그 추가
          "ecr:UntagResource",                   # 태그 제거
          "ecr:ListTagsForResource"              # 태그 목록 조회
        ]
        Resource = "*"
      },
      # 🔑 Secrets Manager 권한 (GitHub 토큰, Docker 자격증명 등)
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",       # Secret 값 가져오기
          "secretsmanager:DescribeSecret"        # Secret 정보 조회
        ]
        Resource = [
          "arn:aws:secretsmanager:ap-northeast-2:${data.aws_caller_identity.current.account_id}:secret:jenkins/*",
          "arn:aws:secretsmanager:ap-northeast-2:${data.aws_caller_identity.current.account_id}:secret:github/*",
          "arn:aws:secretsmanager:ap-northeast-2:${data.aws_caller_identity.current.account_id}:secret:docker/*"
        ]
      },
      # 📦 Parameter Store 권한 (빌드 설정값들)
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",                    # 파라미터 값 가져오기
          "ssm:GetParameters",                   # 여러 파라미터 가져오기
          "ssm:GetParametersByPath"              # 경로별 파라미터 가져오기
        ]
        Resource = [
          "arn:aws:ssm:ap-northeast-2:${data.aws_caller_identity.current.account_id}:parameter/jenkins/*",
          "arn:aws:ssm:ap-northeast-2:${data.aws_caller_identity.current.account_id}:parameter/build/*"
        ]
      },
      # 🐙 CodeCommit 권한 (AWS Git 저장소 사용시)
      {
        Effect = "Allow"
        Action = [
          "codecommit:GitPull",                  # Git 풀
          "codecommit:GitPush",                  # Git 푸시
          "codecommit:GetBranch",                # 브랜치 정보
          "codecommit:GetCommit",                # 커밋 정보
          "codecommit:GetRepository",            # 저장소 정보
          "codecommit:ListBranches",             # 브랜치 목록
          "codecommit:ListRepositories"          # 저장소 목록
        ]
        Resource = "*"
      },
      # 📊 CloudWatch Logs 권한 (빌드 로그 저장)
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",                 # 로그 그룹 생성
          "logs:CreateLogStream",                # 로그 스트림 생성
          "logs:PutLogEvents",                   # 로그 이벤트 전송
          "logs:DescribeLogGroups",              # 로그 그룹 조회
          "logs:DescribeLogStreams"              # 로그 스트림 조회
        ]
        Resource = [
          "arn:aws:logs:ap-northeast-2:${data.aws_caller_identity.current.account_id}:log-group:/jenkins/*",
          "arn:aws:logs:ap-northeast-2:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/*"
        ]
      },
      # 🏗️ S3 권한 (아티팩트 저장 및 캐시)
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",                        # 객체 다운로드
          "s3:PutObject",                        # 객체 업로드
          "s3:DeleteObject",                     # 객체 삭제
          "s3:ListBucket",                       # 버킷 목록
          "s3:GetBucketLocation"                 # 버킷 위치 정보
        ]
        Resource = [
          "arn:aws:s3:::${local.project_name}-*-jenkins-artifacts",
          "arn:aws:s3:::${local.project_name}-*-jenkins-artifacts/*",
          "arn:aws:s3:::${local.project_name}-*-build-cache",
          "arn:aws:s3:::${local.project_name}-*-build-cache/*"
        ]
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name      = "${local.project_name}-${local.environment}-jenkins-agent-build-policy"
    Component = "Jenkins-Agent-Build"
  })
}

# 정책 연결
resource "aws_iam_role_policy_attachment" "jenkins_agent_build_policy_attachment" {
  role       = aws_iam_role.jenkins_agent_ecr_role.name
  policy_arn = aws_iam_policy.jenkins_agent_build_policy.arn
}

#==============================================================================
# Kaniko ECR 인증용 Secret
#==============================================================================
resource "kubernetes_secret" "kaniko_ecr_config" {
  metadata {
    name      = "kaniko-ecr-config"
    namespace = local.jenkins_namespace

    labels = {
      "app.kubernetes.io/name"      = "jenkins"
      "app.kubernetes.io/component" = "kaniko-auth"
    }
  }

  # ECR credential helper 설정
  data = {
    "config.json" = jsonencode({
      credHelpers = {
        # AWS 계정의 ECR 레지스트리 URL 패턴
        "${data.aws_caller_identity.current.account_id}.dkr.ecr.ap-northeast-2.amazonaws.com" = "ecr-login"
      }
    })
  }

  type = "Opaque"
}

#==============================================================================
# Jenkins 에이전트용 ServiceAccount
#==============================================================================
resource "kubernetes_service_account" "jenkins_agent" {
  metadata {
    name      = "jenkins-agent"
    namespace = local.jenkins_namespace

    labels = {
      "app.kubernetes.io/name"      = "jenkins"
      "app.kubernetes.io/component" = "agent"
    }

    # ECR 권한을 위한 IAM 역할 연결
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.jenkins_agent_ecr_role.arn
    }
  }
}

#==============================================================================
# Jenkins 에이전트 Secret (마스터 연결용)
#==============================================================================
resource "kubernetes_secret" "jenkins_agent_secret" {
  metadata {
    name      = "jenkins-agent-secret"
    namespace = local.jenkins_namespace

    labels = {
      "app.kubernetes.io/name"      = "jenkins"
      "app.kubernetes.io/component" = "agent-auth"
    }
  }

  # Jenkins UI에서 발급받은 Secret 키
  data = {
    secret = var.jenkins_agent_secret
  }

  type = "Opaque"
}

#==============================================================================
# Jenkins 에이전트 Deployment
#==============================================================================
resource "kubernetes_deployment" "jenkins_agent" {
  metadata {
    name      = "jenkins-agent"
    namespace = local.jenkins_namespace

    labels = {
      "app.kubernetes.io/name"      = "jenkins"
      "app.kubernetes.io/component" = "agent"
      "app.kubernetes.io/version"   = local.jenkins_agent_image.tag
    }
  }

  spec {
    # 에이전트 Pod 개수
    replicas = local.jenkins_agent_replicas

    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "jenkins"
        "app.kubernetes.io/component" = "agent"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "jenkins"
          "app.kubernetes.io/component" = "agent"
        }

        annotations = {
          # Pod 재시작을 위한 어노테이션
          "kubectl.kubernetes.io/restartedAt" = timestamp()
        }
      }

      spec {
        service_account_name = kubernetes_service_account.jenkins_agent.metadata[0].name

        # 🔧 노드 선택 (시스템 노드에 배치)
        node_selector = local.node_selector

        # 🔧 톨러레이션 설정 (시스템 노드의 taint 허용)
        dynamic "toleration" {
          for_each = local.tolerations
          content {
            key      = toleration.value.key
            operator = toleration.value.operator
            value    = toleration.value.value
            effect   = toleration.value.effect
          }
        }

        # 🔧 스팟 인스턴스 선호도 (비용 절약)
        affinity {
          node_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 50
              preference {
                match_expressions {
                  key      = "karpenter.sh/capacity-type"
                  operator = "In"
                  values   = ["spot"]
                }
              }
            }
          }
        }

        # 🔧 메인 컨테이너: Jenkins JNLP 에이전트
        container {
          name  = "jenkins-agent"
          image = "${local.jenkins_agent_image.repository}:${local.jenkins_agent_image.tag}"
          
          image_pull_policy = local.jenkins_agent_image.pullPolicy

          # 🔧 Jenkins UI에서 제공된 정확한 명령어 사용
          command = [
            "java",
            "-jar",
            "/usr/share/jenkins/agent.jar"
          ]

          # 🔧 Jenkins UI 연결 파라미터 (WebSocket 또는 TCP)
          args = concat([
            "-url", local.jenkins_internal_url,
            "-secret", "$(JENKINS_SECRET)",
            "-name", local.jenkins_agent_name,
            "-workDir", local.jenkins_workdir
          ], local.use_websocket ? ["-webSocket"] : [])

          # 🔧 리소스 설정 (빌드용으로 충분한 리소스)
          resources {
            requests = {
              cpu    = local.jenkins_agent_resources.requests.cpu
              memory = local.jenkins_agent_resources.requests.memory
            }
            limits = {
              cpu    = local.jenkins_agent_resources.limits.cpu
              memory = local.jenkins_agent_resources.limits.memory
            }
          }

          # 🔧 환경 변수
          env {
            name  = "JENKINS_URL"
            value = local.jenkins_internal_url
          }

          env {
            name  = "JENKINS_AGENT_NAME"
            value = local.jenkins_agent_name
          }

          env {
            name  = "JENKINS_AGENT_WORKDIR"
            value = local.jenkins_workdir
          }

          # 🔑 Jenkins Secret 마운트
          env {
            name = "JENKINS_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.jenkins_agent_secret.metadata[0].name
                key  = "secret"
              }
            }
          }

          # 🔧 볼륨 마운트
          volume_mount {
            name       = "workspace"
            mount_path = local.jenkins_workdir
          }

          volume_mount {
            name       = "kaniko-config"
            mount_path = "/kaniko/.docker"
            read_only  = true
          }

          # 🔧 작업 디렉토리
          working_dir = local.jenkins_workdir

          # 🔧 보안 컨텍스트
          security_context {
            run_as_user  = 1000  # jenkins 사용자
            run_as_group = 1000  # jenkins 그룹
          }
        }

        # 🔧 Git 사이드카 컨테이너 (소스코드 클론용)
        container {
          name  = "git"
          image = "${local.git_image.repository}:${local.git_image.tag}"
          
          image_pull_policy = local.git_image.pullPolicy

          # 🔧 Git 리소스 설정 (가볍게)
          resources {
            requests = {
              cpu    = local.git_resources.requests.cpu
              memory = local.git_resources.requests.memory
            }
            limits = {
              cpu    = local.git_resources.limits.cpu
              memory = local.git_resources.limits.memory
            }
          }

          # 🔧 Git 컨테이너가 대기 상태로 유지 (Jenkins에서 필요시 사용)
          command = ["/bin/sh"]
          args    = ["-c", "while true; do sleep 30; done"]

          # 🔧 볼륨 마운트
          volume_mount {
            name       = "workspace"
            mount_path = "/workspace"
          }

          # 🔧 Git 설정 환경변수
          env {
            name  = "GIT_SSL_NO_VERIFY"
            value = "false"  # SSL 검증 활성화 (보안)
          }

          env {
            name  = "GIT_TERMINAL_PROMPT"
            value = "0"  # 터미널 프롬프트 비활성화
          }

          # 🔧 작업 디렉토리
          working_dir = "/workspace"

          # 🔧 보안 컨텍스트
          security_context {
            run_as_user  = 1000  # jenkins 사용자와 동일
            run_as_group = 1000  # jenkins 그룹과 동일
          }
        }

        # 🔧 AWS CLI 사이드카 컨테이너 (AWS 서비스 접근용)
        container {
          name  = "aws-cli"
          image = "${local.aws_cli_image.repository}:${local.aws_cli_image.tag}"
          
          image_pull_policy = local.aws_cli_image.pullPolicy

          # 🔧 AWS CLI 리소스 설정
          resources {
            requests = {
              cpu    = local.aws_cli_resources.requests.cpu
              memory = local.aws_cli_resources.requests.memory
            }
            limits = {
              cpu    = local.aws_cli_resources.limits.cpu
              memory = local.aws_cli_resources.limits.memory
            }
          }

          # 🔧 AWS CLI 컨테이너가 대기 상태로 유지
          command = ["/bin/sh"]
          args    = ["-c", "while true; do sleep 30; done"]

          # 🔧 볼륨 마운트
          volume_mount {
            name       = "workspace"
            mount_path = "/workspace"
          }

          # 🔧 AWS 리전 설정
          env {
            name  = "AWS_DEFAULT_REGION"
            value = "ap-northeast-2"
          }

          env {
            name  = "AWS_REGION"
            value = "ap-northeast-2"
          }

          # 🔧 작업 디렉토리
          working_dir = "/workspace"

          # 🔧 보안 컨텍스트
          security_context {
            run_as_user  = 1000  # jenkins 사용자와 동일
            run_as_group = 1000  # jenkins 그룹과 동일
          }
        }

        # 🔧 Kaniko 사이드카 컨테이너 (이미지 빌드용)
        container {
          name  = "kaniko"
          image = "${local.kaniko_image.repository}:${local.kaniko_image.tag}"
          
          image_pull_policy = local.kaniko_image.pullPolicy

          # 🔧 Kaniko 리소스 설정
          resources {
            requests = {
              cpu    = local.kaniko_resources.requests.cpu
              memory = local.kaniko_resources.requests.memory
            }
            limits = {
              cpu    = local.kaniko_resources.limits.cpu
              memory = local.kaniko_resources.limits.memory
            }
          }

          # 🔧 Kaniko가 대기 상태로 유지 (Jenkins에서 필요시 사용)
          command = ["/busybox/cat"]
          tty     = true
          stdin   = true

          # 🔧 볼륨 마운트 (ECR 인증)
          volume_mount {
            name       = "kaniko-config"
            mount_path = "/kaniko/.docker"
            read_only  = true
          }

          volume_mount {
            name       = "workspace"
            mount_path = "/workspace"
          }

          # 🔧 AWS 리전 설정 (ECR용)
          env {
            name  = "AWS_DEFAULT_REGION"
            value = "ap-northeast-2"
          }

          # 🔧 작업 디렉토리
          working_dir = "/workspace"

          # 🔧 보안 컨텍스트 (루트 권한 필요)
          security_context {
            run_as_user = 0  # root 사용자 (컨테이너 빌드용)
          }
        }

        # 🔧 볼륨 정의
        volume {
          name = "workspace"
          empty_dir {
            size_limit = "10Gi"  # 빌드 작업용 임시 저장소
          }
        }

        volume {
          name = "kaniko-config"
          secret {
            secret_name = kubernetes_secret.kaniko_ecr_config.metadata[0].name
            default_mode = "0644"
          }
        }

        # 🔧 재시작 정책
        restart_policy = "Always"

        # 🔧 DNS 정책
        dns_policy = "ClusterFirst"

        # 🔧 종료 유예 시간 (빌드 중 갑작스러운 종료 방지)
        termination_grace_period_seconds = 300  # 5분

        # 🔧 Pod 레벨 보안 컨텍스트 (파일시스템 권한)
        security_context {
          fs_group = 1000  # jenkins 그룹의 파일시스템 권한
        }
      }
    }
  }

  depends_on = [
    kubernetes_service_account.jenkins_agent,
    kubernetes_secret.jenkins_agent_secret,
    kubernetes_secret.kaniko_ecr_config
  ]
}

#==============================================================================
# Jenkins 에이전트 Service (JNLP 통신용)
#==============================================================================
resource "kubernetes_service" "jenkins_agent" {
  metadata {
    name      = "jenkins-agent"
    namespace = local.jenkins_namespace

    labels = {
      "app.kubernetes.io/name"      = "jenkins"
      "app.kubernetes.io/component" = "agent"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name"      = "jenkins"
      "app.kubernetes.io/component" = "agent"
    }

    # JNLP 프로토콜 포트 (Jenkins 마스터와 통신)
    port {
      name        = "jnlp"
      port        = 50000
      target_port = 50000
      protocol    = "TCP"
    }

    # 클러스터 내부 통신만
    type = "ClusterIP"
  }

  depends_on = [kubernetes_deployment.jenkins_agent]
} 