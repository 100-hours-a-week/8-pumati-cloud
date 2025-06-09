#==============================================================================
# 06-ci: Jenkins CI/CD 시스템 구성
#==============================================================================

# 🎯 Jenkins 구성 목표:
# EBS 볼륨 연결: 01-static에서 생성한 EBS를 Jenkins 마스터에 연결
# 자동 에이전트: Kubernetes 플러그인으로 필요시 에이전트 Pod 자동 생성
# 스팟 인스턴스 활용: 에이전트는 저렴한 스팟 노드에서 실행
# 간결한 구성: 공식 Helm 차트 사용으로 최소 설정

#==============================================================================
# Jenkins 네임스페이스 생성
#==============================================================================
resource "kubernetes_namespace" "jenkins" {
  metadata {
    name = "jenkins"

    labels = {
      name                          = "jenkins"
      "app.kubernetes.io/name"      = "jenkins"
      "app.kubernetes.io/component" = "ci-cd"
    }
  }
}

#==============================================================================
# Jenkins용 StorageClass 생성
#==============================================================================
resource "kubernetes_storage_class" "jenkins_ebs_direct" {
  metadata {
    name = "jenkins-ebs-direct"

    labels = {
      "app.kubernetes.io/name"      = "jenkins"
      "app.kubernetes.io/component" = "storage"
    }
  }

  # EBS CSI 드라이버 사용
  storage_provisioner = "ebs.csi.aws.com"

  # 볼륨 바인딩 모드 - 즉시 바인딩
  volume_binding_mode = "Immediate"

  # 파라미터 설정
  parameters = {
    type      = "gp3"
    fsType    = "ext4"
    encrypted = "true"
  }

  # PV 삭제 시 정책
  reclaim_policy = "Retain"

  # 볼륨 확장 허용
  allow_volume_expansion = true
}

#==============================================================================
# Jenkins 마스터용 PV (01-static의 EBS 볼륨 사용)
#==============================================================================
resource "kubernetes_persistent_volume" "jenkins_master" {
  metadata {
    name = "jenkins-master-pv"

    labels = {
      "app.kubernetes.io/name"      = "jenkins"
      "app.kubernetes.io/component" = "master-storage"
    }
  }

  spec {
    capacity = {
      storage = "${local.jenkins_ebs_size}Gi"
    }

    access_modes = ["ReadWriteOnce"]

    # EBS 볼륨 연결 설정
    persistent_volume_source {
      aws_elastic_block_store {
        volume_id = local.jenkins_ebs_volume_id
        fs_type   = "ext4"
      }
    }

    # 볼륨이 위치한 가용영역 지정
    node_affinity {
      required {
        node_selector_term {
          match_expressions {
            key      = "topology.kubernetes.io/zone"
            operator = "In"
            values   = [local.jenkins_ebs_availability_zone]
          }
        }
      }
    }

    # PV 삭제 시에도 EBS 볼륨은 보존
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = kubernetes_storage_class.jenkins_ebs_direct.metadata[0].name
  }

  # StorageClass 생성 후에 PV 생성
  depends_on = [kubernetes_storage_class.jenkins_ebs_direct]
}

#==============================================================================
# Jenkins 마스터용 PVC
#==============================================================================
resource "kubernetes_persistent_volume_claim" "jenkins_master" {
  metadata {
    name      = "jenkins-master-pvc"
    namespace = kubernetes_namespace.jenkins.metadata[0].name

    labels = {
      "app.kubernetes.io/name"      = "jenkins"
      "app.kubernetes.io/component" = "master-storage"
    }
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = kubernetes_storage_class.jenkins_ebs_direct.metadata[0].name

    resources {
      requests = {
        storage = "${local.jenkins_ebs_size}Gi"
      }
    }

    # 특정 PV에 바인딩
    volume_name = kubernetes_persistent_volume.jenkins_master.metadata[0].name
  }

  depends_on = [
    kubernetes_persistent_volume.jenkins_master,
    kubernetes_storage_class.jenkins_ebs_direct
  ]
}

#==============================================================================
# Jenkins용 클러스터 역할 (Helm이 ServiceAccount 생성 후 바인딩용)
#==============================================================================
# Jenkins가 필요한 Kubernetes 리소스에 접근할 수 있는 클러스터 역할
resource "kubernetes_cluster_role" "jenkins" {
  metadata {
    name = "jenkins-cluster-role"

    labels = {
      "app.kubernetes.io/name"      = "jenkins"
      "app.kubernetes.io/component" = "rbac"
    }
  }

  # Pod 관리 권한 (에이전트 생성/삭제)
  rule {
    api_groups = [""]
    resources  = ["pods", "pods/exec", "pods/log", "pods/portforward"]
    verbs      = ["create", "delete", "get", "list", "patch", "update", "watch"]
  }

  # 서비스 계정 관리
  rule {
    api_groups = [""]
    resources  = ["serviceaccounts"]
    verbs      = ["get", "list", "watch"]
  }

  # ConfigMap 및 Secret 관리
  rule {
    api_groups = [""]
    resources  = ["configmaps", "secrets"]
    verbs      = ["create", "delete", "get", "list", "patch", "update", "watch"]
  }

  # PVC 관리 (에이전트용 임시 볼륨)
  rule {
    api_groups = [""]
    resources  = ["persistentvolumeclaims"]
    verbs      = ["create", "delete", "get", "list", "patch", "update", "watch"]
  }

  # 네임스페이스 정보 조회
  rule {
    api_groups = [""]
    resources  = ["namespaces"]
    verbs      = ["get", "list", "watch"]
  }

  # 노드 정보 조회 (에이전트 스케줄링용)
  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["get", "list", "watch"]
  }
}

# ECR 접근용 IAM 역할
resource "aws_iam_role" "jenkins_ecr_role" {
  name = "${local.project_name}-${local.environment}-jenkins-ecr-role"

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
            "${local.cluster_oidc_issuer}:sub" = "system:serviceaccount:jenkins:jenkins"
            "${local.cluster_oidc_issuer}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name      = "${local.project_name}-${local.environment}-jenkins-ecr-role"
    Component = "Jenkins-ECR"
  })
}

# ECR 권한 정책
resource "aws_iam_policy" "jenkins_ecr_policy" {
  name        = "${local.project_name}-${local.environment}-jenkins-ecr-policy"
  description = "Jenkins ECR access policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:CreateRepository",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages"
        ]
        Resource = "*"
      }
    ]
  })
}

# 정책 연결
resource "aws_iam_role_policy_attachment" "jenkins_ecr_policy_attachment" {
  role       = aws_iam_role.jenkins_ecr_role.name
  policy_arn = aws_iam_policy.jenkins_ecr_policy.arn
}

#==============================================================================
# Jenkins Helm 차트 설치
#==============================================================================
# 공식 Jenkins Helm 차트를 사용하여 간결하고 표준적인 구성
resource "helm_release" "jenkins" {
  name       = "jenkins"
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  version    = "5.7.20"
  namespace  = kubernetes_namespace.jenkins.metadata[0].name

  create_namespace = false

  force_update  = true
  recreate_pods = true

  values = [
    yamlencode({
      # 컨트롤러 설정 (Jenkins 마스터)
      controller = {
        # 🔧 1. Java 21 이미지로 업그레이드
        image = {
          repository = "jenkins/jenkins"
          tag        = "2.492.2-jdk21" # Java 17 → Java 21
          pullPolicy = "IfNotPresent"
        }

        # 🔧 2. 관리자 계정 설정 (보안 문제 해결)
        admin = {
          username = "admin"
          password = "admin123!" # 첫 로그인 후 반드시 변경
        }

        # 리소스 설정 - t3.medium에 최적화
        resources = {
          requests = {
            cpu    = "1000m" # 1 vCPU 요청
            memory = "2Gi"   # 2GB 메모리 요청
          }
          limits = {
            cpu    = "1800m"  # 1.8 vCPU 제한 (90%)
            memory = "3500Mi" # 3.5GB 메모리 제한 (노드 여유 공간 확보)
          }
        }

        # 🔧 Jenkins URL 설정 강화
        jenkinsUrl       = "http://jenkins.jenkins.svc.cluster.local:8080"
        jenkinsUriPrefix = "/"

        # 🔧 마스터에서 빌드 실행 비활성화 (중요!)
        numExecutors = 0 # 마스터에서 빌드 작업 실행 금지

        # 🔧 플러그인 설치 - 최소한만 추가 (Kubernetes 플러그인만)
        installPlugins = [
          # "kubernetes:4246.v5a_12b_1fe120e"  # Kubernetes 플러그인만 추가 (에이전트 동적 생성용)
        ]

        # 추가 플러그인 비활성화
        additionalPlugins = []

        # 플러그인 설치 관련 설정
        initContainerEnv = []

        # 🔧 JCasC 설정 - Kubernetes 클라우드 기본 설정만 (Pod 템플릿 제외)
        JCasC = {
          defaultConfig = false
          configScripts = {
            jenkins-config = yamlencode({
              jenkins = {
                # 🔥 보안 설정
                securityRealm = {
                  local = {
                    allowsSignup = false
                    users = [
                      {
                        id       = "admin"
                        password = "admin123!"
                      }
                    ]
                  }
                }
                authorizationStrategy = {
                  loggedInUsersCanDoAnything = {
                    allowAnonymousRead = false
                  }
                }
                
                # 🔥 기본 Kubernetes 클라우드만 설정 (Pod 템플릿은 Jenkinsfile에서 정의)
                clouds = [
                  {
                    kubernetes = {
                      name          = "kubernetes"
                      serverUrl     = "https://kubernetes.default.svc"
                      namespace     = "jenkins"
                      # ⭐️ WebSocket 방식: 외부 도메인 URL 사용 (에이전트가 ALB를 통해 연결)
                      jenkinsUrl    = "https://jenkins.${local.domain_name}"
                      # ⭐️ WebSocket 사용 시 jenkinsTunnel은 비워둠 (설정하면 TCP 모드로 강제됨)
                      # jenkinsTunnel = ""  # 명시적으로 비워둠
                      # ⭐️ WebSocket 활성화 - ALB가 HTTP(S) 업그레이드 자동 지원
                      webSocket     = true
                      containerCap  = 20
                      maxRequestsPerHost = 32
                      skipTlsVerify = true
                      # Pod 템플릿은 Jenkinsfile에서 inline으로 정의
                    }
                  }
                ]
              }
            })
          }
        }

        # 🔥 JVM 옵션 - t3.medium에 맞춘 넉넉한 설정
        javaOpts = join(" ", [
          "-Xms1536m",                 # 초기 힙: 1.5GB
          "-Xmx2560m",                 # 최대 힙: 2.5GB
          "-XX:MaxMetaspaceSize=512m", # 메타스페이스: 512MB
          "-XX:+UseG1GC",
          "-XX:+UseStringDeduplication",
          "-XX:+UseContainerSupport",
          "-XX:MaxGCPauseMillis=100",
          "-XX:+DisableExplicitGC",
          "-Dhudson.model.DirectoryBrowserSupport.CSP=",
          "-Djava.awt.headless=true",
          "-Dhudson.model.Jenkins.locationConfiguration.url=https://jenkins.${local.domain_name}/",
          "-Dhudson.model.Jenkins.rootUrl=https://jenkins.${local.domain_name}/",
          "-Djenkins.model.Jenkins.locationConfiguration.adminAddress=admin@${local.domain_name}",
          "-Duser.timezone=Asia/Seoul"
        ])

        # 🔥 Jenkins 환경 변수로도 강제 설정
        containerEnv = [
          {
            name  = "JENKINS_URL"
            value = "https://jenkins.${local.domain_name}/"
          },
          {
            name  = "JENKINS_ROOT_URL"
            value = "https://jenkins.${local.domain_name}/"
          }
        ]

        # 서비스 계정 설정
        serviceAccount = {
          create = true
          name   = "jenkins"
          annotations = {
            "eks.amazonaws.com/role-arn" = aws_iam_role.jenkins_ecr_role.arn
          }
        }

        # 보안 컨텍스트
        securityContext = {
          runAsUser  = 1000
          runAsGroup = 1000
          fsGroup    = 1000
        }

        # 영구 볼륨 설정
        persistence = {
          enabled       = true
          existingClaim = "jenkins-master-pvc"
          storageClass  = kubernetes_storage_class.jenkins_ebs_direct.metadata[0].name
          accessMode    = "ReadWriteOnce"
          size          = "50Gi"
        }

        # 서비스 설정
        service = {
          type = "ClusterIP"
          port = 8080
        }

        # Ingress 설정에서 모든 하위 경로 허용 확인
        ingress = {
          enabled = true
          annotations = {
            "kubernetes.io/ingress.class"                = "alb"
            "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
            "alb.ingress.kubernetes.io/target-type"      = "ip"
            "alb.ingress.kubernetes.io/listen-ports"     = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
            "alb.ingress.kubernetes.io/ssl-redirect"     = "443"
            "alb.ingress.kubernetes.io/certificate-arn"  = local.acm_certificate_arn
            "alb.ingress.kubernetes.io/healthcheck-path" = "/login"
            "external-dns.alpha.kubernetes.io/hostname"  = "jenkins.${local.domain_name}"

            # 헤더 보존 설정
            "alb.ingress.kubernetes.io/load-balancer-attributes" = join(",", [
              "routing.http.preserve_host_header.enabled=true",
              "routing.http.xff_header_processing.mode=append"
            ])
            
            # ⭐️ WebSocket 지원을 위한 타임아웃 설정 (긴 빌드 대응)
            "alb.ingress.kubernetes.io/backend-protocol-version" = "HTTP1"
          }
          hostName = "jenkins.${local.domain_name}"
          path     = "/*"
          pathType = "Prefix" # 모든 하위 경로 포함 (/static/ 포함)

          tls = [
            {
              secretName = "jenkins-tls"
              hosts      = ["jenkins.${local.domain_name}"]
            }
          ]
        }

        # 💥 agentListenerService는 레거시 TCP 방식이므로 제거합니다.
        # agentListenerService = {
        #   enabled = true
        #   type    = "ClusterIP"
        #   port    = 50000
        #   name    = "jenkins-agent"
        # }

        # 노드 선택 (시스템 노드에 배치)
        # nodeSelector = {
        #   "node-type" = "system"
        # }

        # 톨러레이션 (시스템 노드의 taint 허용)
        tolerations = [
          {
            key      = "node-type"
            operator = "Equal"
            value    = "system"
            effect   = "NoSchedule"
          }
        ]

        # 가용영역 제한 (EBS 볼륨과 같은 AZ)
        affinity = {
          nodeAffinity = {
            requiredDuringSchedulingIgnoredDuringExecution = {
              nodeSelectorTerms = [
                {
                  matchExpressions = [
                    {
                      key      = "topology.kubernetes.io/zone"
                      operator = "In"
                      values   = [local.jenkins_ebs_availability_zone]
                    }
                  ]
                }
              ]
            }
          }
        }

        # 헬스체크 설정
        healthProbes = true
        probes = {
          startupProbe = {
            httpGet = {
              path = "/login"
              port = "http"
            }
            initialDelaySeconds = 60
            periodSeconds       = 10
            timeoutSeconds      = 5
            failureThreshold    = 12
          }
          livenessProbe = {
            httpGet = {
              path = "/login"
              port = "http"
            }
            initialDelaySeconds = 90
            periodSeconds       = 10
            timeoutSeconds      = 5
            failureThreshold    = 5
          }
          readinessProbe = {
            httpGet = {
              path = "/login"
              port = "http"
            }
            initialDelaySeconds = 30
            periodSeconds       = 10
            timeoutSeconds      = 5
            failureThreshold    = 3
          }
        }
      }

      # ⭐️ 에이전트 WebSocket 설정 - 핵심 옵션!
      agent = {
        enabled   = false     # 정적 에이전트는 비활성화 (동적 에이전트만 사용)
        websocket = true      # 🔥 핵심: WebSocket 방식 활성화
        podName   = "jenkins-agent-{{.Build.Number}}-{{randAlphaNum 5}}"
      }

      # 🔥 StatefulSet의 volumeClaimTemplates 비활성화
      persistence = {
        enabled       = true
        existingClaim = "jenkins-master-pvc"
        storageClass  = kubernetes_storage_class.jenkins_ebs_direct.metadata[0].name
        accessMode    = "ReadWriteOnce"
        size          = "50Gi"
      }
    })
  ]

  # Jenkins가 완전히 시작될 때까지 대기
  wait          = true
  wait_for_jobs = true
  timeout       = 600 # 뜨는데 5~10분 사이로 걸리는 듯

  # 🚨 중요: PVC 삭제 순서 문제 해결
  lifecycle {
    create_before_destroy = false
  }

  # depends_on에서 PVC 의존성 제거하여 순환 의존성 해결
  depends_on = [
    kubernetes_cluster_role.jenkins
  ]
}

#==============================================================================
# Helm이 생성한 ServiceAccount에 클러스터 역할 바인딩
#==============================================================================
# Helm 설치 완료 후 생성된 ServiceAccount에 권한 부여
resource "kubernetes_cluster_role_binding" "jenkins" {
  metadata {
    name = "jenkins-cluster-role-binding"

    labels = {
      "app.kubernetes.io/name"      = "jenkins"
      "app.kubernetes.io/component" = "rbac"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.jenkins.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "jenkins" # Helm이 생성한 ServiceAccount 이름
    namespace = kubernetes_namespace.jenkins.metadata[0].name
  }

  depends_on = [helm_release.jenkins]
}


