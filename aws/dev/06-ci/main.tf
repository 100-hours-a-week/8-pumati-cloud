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
# Jenkins 마스터용 PV (01-static의 EBS 볼륨 사용)
#==============================================================================
# 01-static에서 생성한 EBS 볼륨을 Kubernetes PV로 연결
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
    storage_class_name               = "jenkins-ebs-direct"
  }
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
    storage_class_name = "jenkins-ebs-direct"

    resources {
      requests = {
        storage = "${local.jenkins_ebs_size}Gi"
      }
    }

    # 특정 PV에 바인딩
    volume_name = kubernetes_persistent_volume.jenkins_master.metadata[0].name
  }

  depends_on = [kubernetes_persistent_volume.jenkins_master]
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
    Name = "${local.project_name}-${local.environment}-jenkins-ecr-role"
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

        # 리소스 설정
        resources = {
          requests = {
            cpu    = "1000m"
            memory = "1Gi"
          }
          limits = {
            cpu    = "1500m"
            memory = "1Gi"
          }
        }

        # 🔧 Jenkins URL 설정 강화
        jenkinsUrl       = "https://jenkins.${local.domain_name}"
        jenkinsUriPrefix = "/"

        # 🔧 JCasC로 Jenkins URL과 보안 설정 추가
        JCasC = {
          defaultConfig = true
          configScripts = {
            jenkins-config = yamlencode({
              jenkins = {
                # Jenkins 위치 설정 (중요!)
                locationConfiguration = {
                  url = "https://jenkins.${local.domain_name}/"
                  adminAddress = "admin@${local.domain_name}"
                }
                
                # 보안 설정
                securityRealm = {
                  local = {
                    allowsSignup = false
                    users = [
                      {
                        id = "admin"
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
              }
              
              unclassified = {
                # Jenkins 위치 재확인
                location = {
                  url = "https://jenkins.${local.domain_name}/"
                  adminAddress = "admin@${local.domain_name}"
                }
                
                # 🔥 정적 리소스 설정 추가
                resourceRoot = {
                  url = "https://jenkins.${local.domain_name}/"
                }
              }
            })
          }
        }

        # 🔥 JVM 옵션에 정적 리소스 관련 설정 추가
        javaOpts = join(" ", [
          "-Xms512m",
          "-Xmx1g",
          "-Dhudson.model.DirectoryBrowserSupport.CSP=",
          "-Djenkins.install.runSetupWizard=false",
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
          existingClaim = "jenkins-master-pvc" # 원래 이름 유지
          # storageClass 키 완전 제거
          accessMode = "ReadWriteOnce"
          size       = "50Gi" # EBS 볼륨과 같은 크기로
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
          }
          hostName = "jenkins.${local.domain_name}"
          path     = "/*"
          pathType = "Prefix"  # 모든 하위 경로 포함 (/static/ 포함)

          tls = [
            {
              secretName = "jenkins-tls"
              hosts      = ["jenkins.${local.domain_name}"]
            }
          ]
        }

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

        # 🔧 플러그인 설치 완전 비활성화
        installPlugins = []  # 주석 해제하고 빈 배열로 설정
        
        # 추가 플러그인도 비활성화
        additionalPlugins = []
        
        # 플러그인 설치 관련 init 컨테이너 비활성화
        initContainerEnv = [
          {
            name  = "SKIP_PLUGIN_INSTALL"
            value = "true"
          }
        ]
        
        # 플러그인 관리자 비활성화
        pluginManager = {
          enabled = false
        }
      }

      # 에이전트 설정 비활성화
      agent = {
        enabled = false
      }

      # 글로벌 레벨에서도 StatefulSet 관련 설정 비활성화
      statefulSet = {
        enabled = false
      }

      # 글로벌 레벨에서도 volumeClaimTemplates 비활성화
      volumeClaimTemplates = []

      # 글로벌 레벨에서 persistence 설정
      persistence = {
        enabled       = true
        existingClaim = "jenkins-master-pvc"
        storageClass  = ""
      }
    })
  ]

  # Jenkins가 완전히 시작될 때까지 대기
  wait          = true
  wait_for_jobs = true
  timeout       = 480 # 뜨는데 5~10분 사이로 걸리는 듯

  depends_on = [
    kubernetes_persistent_volume_claim.jenkins_master,
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


