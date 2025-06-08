# ArgoCD 네임스페이스 생성
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    
    labels = {
      name = "argocd"
      "app.kubernetes.io/name" = "argocd"
    }
  }
}

# ArgoCD 서버용 서비스 계정 생성
resource "kubernetes_service_account" "argocd_server" {
  metadata {
    name      = "argocd-server"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.argocd_server.arn
    }
  }
}

# ArgoCD 컨트롤러용 서비스 계정 생성
resource "kubernetes_service_account" "argocd_application_controller" {
  metadata {
    name      = "argocd-application-controller"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.argocd_controller.arn
    }
  }
}

# ArgoCD Repo Server용 서비스 계정 생성
resource "kubernetes_service_account" "argocd_repo_server" {
  metadata {
    name      = "argocd-repo-server"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.argocd_repo_server.arn
    }
  }
}

# ArgoCD 서버용 IAM 역할 생성 (수정된 버전)
resource "aws_iam_role" "argocd_server" {
  name = "${local.project_name}-${local.environment}-argocd-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = data.terraform_remote_state.eks.outputs.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(data.terraform_remote_state.eks.outputs.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:argocd:argocd-server"
            "${replace(data.terraform_remote_state.eks.outputs.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# ArgoCD 컨트롤러용 IAM 역할 생성 (수정된 버전)
resource "aws_iam_role" "argocd_controller" {
  name = "${local.project_name}-${local.environment}-argocd-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = data.terraform_remote_state.eks.outputs.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(data.terraform_remote_state.eks.outputs.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:argocd:argocd-application-controller"
            "${replace(data.terraform_remote_state.eks.outputs.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# ArgoCD Repo Server용 IAM 역할 생성 (수정된 버전)
resource "aws_iam_role" "argocd_repo_server" {
  name = "${local.project_name}-${local.environment}-argocd-repo-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = data.terraform_remote_state.eks.outputs.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(data.terraform_remote_state.eks.outputs.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:argocd:argocd-repo-server"
            "${replace(data.terraform_remote_state.eks.outputs.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# ArgoCD 서버용 IAM 정책 연결 (GitOps 운영에 필요한 모든 권한)
resource "aws_iam_role_policy" "argocd_server_policy" {
  name = "${local.project_name}-${local.environment}-argocd-server-policy"
  role = aws_iam_role.argocd_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # 🐳 ECR 접근 권한 (컨테이너 이미지 pull)
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",           # ECR 로그인 토큰 획득
          "ecr:BatchCheckLayerAvailability",     # 이미지 레이어 존재 확인
          "ecr:GetDownloadUrlForLayer",          # 이미지 레이어 다운로드 URL 획득
          "ecr:BatchGetImage",                   # 이미지 매니페스트 획득
          "ecr:DescribeRepositories",            # ECR 저장소 정보 조회
          "ecr:DescribeImages",                  # 이미지 정보 조회
          "ecr:ListImages"                       # 이미지 목록 조회
        ]
        Resource = "*"
      },
      
      # 🔐 Secrets Manager 접근 권한 (DB 비밀번호, API 키 등)
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",       # 시크릿 값 조회
          "secretsmanager:DescribeSecret",       # 시크릿 메타데이터 조회
          "secretsmanager:ListSecrets"           # 시크릿 목록 조회
        ]
        Resource = "*"
      },
      
      # 📋 Systems Manager Parameter Store 접근 권한 (설정값 관리)
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",                    # 파라미터 값 조회
          "ssm:GetParameters",                   # 여러 파라미터 값 조회
          "ssm:GetParametersByPath",             # 경로별 파라미터 조회
          "ssm:DescribeParameters"               # 파라미터 메타데이터 조회
        ]
        Resource = "*"
      },
      
      # 📊 CloudWatch 로그 권한 (ArgoCD 로그 기록)
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",                 # 로그 그룹 생성
          "logs:CreateLogStream",                # 로그 스트림 생성
          "logs:PutLogEvents",                   # 로그 이벤트 기록
          "logs:DescribeLogGroups",              # 로그 그룹 조회
          "logs:DescribeLogStreams"              # 로그 스트림 조회
        ]
        Resource = "*"
      },
      
      # ☸️ EKS 클러스터 정보 조회 권한 (클러스터 상태 확인)
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",                 # 클러스터 정보 조회
          "eks:ListClusters",                    # 클러스터 목록 조회
          "eks:DescribeNodegroup",               # 노드 그룹 정보 조회
          "eks:ListNodegroups"                   # 노드 그룹 목록 조회
        ]
        Resource = "*"
      },
      
      # 🏷️ 태그 관리 권한 (리소스 태깅)
      {
        Effect = "Allow"
        Action = [
          "tag:GetResources",                    # 태그된 리소스 조회
          "tag:TagResources",                    # 리소스에 태그 추가
          "tag:UntagResources"                   # 리소스에서 태그 제거
        ]
        Resource = "*"
      },
      
      # 🔍 EC2 인스턴스 정보 조회 권한 (노드 상태 확인)
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",               # EC2 인스턴스 정보 조회
          "ec2:DescribeInstanceTypes",           # 인스턴스 타입 정보 조회
          "ec2:DescribeAvailabilityZones",       # 가용 영역 정보 조회
          "ec2:DescribeSubnets",                 # 서브넷 정보 조회
          "ec2:DescribeSecurityGroups"           # 보안 그룹 정보 조회
        ]
        Resource = "*"
      },
      
      # 📈 CloudWatch 메트릭 권한 (모니터링)
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",            # 커스텀 메트릭 전송
          "cloudwatch:GetMetricStatistics",      # 메트릭 통계 조회
          "cloudwatch:ListMetrics"               # 메트릭 목록 조회
        ]
        Resource = "*"
      },
      
      # 🔔 SNS 알림 권한 (배포 알림)
      {
        Effect = "Allow"
        Action = [
          "sns:Publish",                         # SNS 메시지 발송
          "sns:ListTopics",                      # SNS 토픽 목록 조회
          "sns:GetTopicAttributes"               # SNS 토픽 속성 조회
        ]
        Resource = "*"
      },
      
      # 🗄️ S3 접근 권한 (Helm 차트, 설정 파일 저장소)
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",                        # S3 객체 다운로드
          "s3:PutObject",                        # S3 객체 업로드
          "s3:DeleteObject",                     # S3 객체 삭제
          "s3:ListBucket",                       # S3 버킷 내용 조회
          "s3:GetBucketLocation"                 # S3 버킷 위치 조회
        ]
        Resource = [
          "arn:aws:s3:::${local.project_name}-*",
          "arn:aws:s3:::${local.project_name}-*/*"
        ]
      }
    ]
  })
}

# ArgoCD 컨트롤러용 IAM 정책 (Kubernetes 리소스 관리 + ECR 접근)
resource "aws_iam_role_policy" "argocd_controller_policy" {
  name = "${local.project_name}-${local.environment}-argocd-controller-policy"
  role = aws_iam_role.argocd_controller.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # 🐳 ECR 접근 권한 (컨테이너 이미지 pull - 가장 중요!)
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories",
          "ecr:DescribeImages",
          "ecr:ListImages"
        ]
        Resource = "*"
      },
      
      # 🔐 Secrets Manager 접근 (애플리케이션 시크릿 관리)
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets"
        ]
        Resource = "*"
      },
      
      # 📋 Parameter Store 접근 (설정값 관리)
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "ssm:DescribeParameters"
        ]
        Resource = "*"
      },
      
      # 📊 CloudWatch 로그 (배포 로그 기록)
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      },
      
      # ☸️ EKS 클러스터 정보 조회
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "*"
      }
    ]
  })
}

# ArgoCD Repo Server용 IAM 정책 (Git 저장소 + Helm 차트 접근)
resource "aws_iam_role_policy" "argocd_repo_server_policy" {
  name = "${local.project_name}-${local.environment}-argocd-repo-server-policy"
  role = aws_iam_role.argocd_repo_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # 🐳 ECR 접근 권한 (Helm 차트에서 이미지 정보 확인)
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories",
          "ecr:DescribeImages",
          "ecr:ListImages"
        ]
        Resource = "*"
      },
      
      # 🗄️ S3 접근 권한 (Helm 차트 저장소)
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::${local.project_name}-*",
          "arn:aws:s3:::${local.project_name}-*/*"
        ]
      },
      
      # 🔐 Secrets Manager 접근 (Git 인증 정보)
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      },
      
      # 📊 CloudWatch 로그
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

#==============================================================================
# ArgoCD용 StorageClass 생성 (Jenkins 패턴과 동일)
#==============================================================================
resource "kubernetes_storage_class" "argocd_ebs_direct" {
  metadata {
    name = "argocd-ebs-direct"

    labels = {
      "app.kubernetes.io/name"      = "argocd"
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
# ArgoCD 서버용 PV (01-static의 EBS 볼륨 사용)
#==============================================================================
resource "kubernetes_persistent_volume" "argocd_server" {
  metadata {
    name = "argocd-server-pv"

    labels = {
      "app.kubernetes.io/name"      = "argocd"
      "app.kubernetes.io/component" = "server-storage"
    }
  }

  spec {
    capacity = {
      storage = "${data.terraform_remote_state.static.outputs.argocd_server_ebs_size}Gi"
    }

    access_modes = ["ReadWriteOnce"]

    # EBS 볼륨 연결 설정
    persistent_volume_source {
      aws_elastic_block_store {
        volume_id = data.terraform_remote_state.static.outputs.argocd_server_ebs_volume_id
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
            values   = [data.terraform_remote_state.static.outputs.argocd_server_ebs_availability_zone]
          }
        }
      }
    }

    # PV 삭제 시에도 EBS 볼륨은 보존
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = kubernetes_storage_class.argocd_ebs_direct.metadata[0].name
  }

  # StorageClass 생성 후에 PV 생성
  depends_on = [kubernetes_storage_class.argocd_ebs_direct]
}

#==============================================================================
# ArgoCD 서버용 PVC
#==============================================================================
resource "kubernetes_persistent_volume_claim" "argocd_server" {
  metadata {
    name      = "argocd-server-pvc"
    namespace = kubernetes_namespace.argocd.metadata[0].name

    labels = {
      "app.kubernetes.io/name"      = "argocd"
      "app.kubernetes.io/component" = "server-storage"
    }
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = kubernetes_storage_class.argocd_ebs_direct.metadata[0].name

    resources {
      requests = {
        storage = "${data.terraform_remote_state.static.outputs.argocd_server_ebs_size}Gi"
      }
    }

    # 특정 PV에 바인딩
    volume_name = kubernetes_persistent_volume.argocd_server.metadata[0].name
  }

  depends_on = [
    kubernetes_persistent_volume.argocd_server,
    kubernetes_storage_class.argocd_ebs_direct
  ]
}

# ArgoCD Helm 차트 설치 (올바른 볼륨 마운트 경로)
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "5.51.6"
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [
    yamlencode({
      # 🎯 시스템 노드에 모든 컴포넌트 배치
      global = {
        domain = "argocd.${local.domain_name}"
        nodeSelector = {
          "node-type" = "system"
        }
      }

      # ArgoCD 서버 설정 (충돌하지 않는 경로 사용)
      server = {
        serviceAccount = {
          create = false
          name   = kubernetes_service_account.argocd_server.metadata[0].name
        }

        replicas = 1

        # 🎯 EBS 볼륨 연결 (충돌하지 않는 경로)
        volumes = [
          {
            name = "argocd-server-data"
            persistentVolumeClaim = {
              claimName = kubernetes_persistent_volume_claim.argocd_server.metadata[0].name
            }
          }
        ]

        volumeMounts = [
          {
            name      = "argocd-server-data"
            mountPath = "/var/lib/argocd"  # 🔧 충돌하지 않는 데이터 저장 경로
          }
        ]

        # 🔧 AWS Load Balancer Controller용 Ingress 설정
        ingress = {
          enabled = true
          ingressClassName = "alb"
          annotations = {
            "alb.ingress.kubernetes.io/scheme" = "internet-facing"
            "alb.ingress.kubernetes.io/target-type" = "ip"
            "alb.ingress.kubernetes.io/ssl-redirect" = "443"
            "alb.ingress.kubernetes.io/certificate-arn" = data.terraform_remote_state.static.outputs.acm_certificate_arn
            "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
            "external-dns.alpha.kubernetes.io/hostname" = "argocd.${local.domain_name}"
          }
          
          hosts = ["argocd.${local.domain_name}"]
          tls = []
        }

        # 🔧 HTTP 모드로 실행
        extraArgs = ["--insecure"]
        
        resources = {
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
          requests = {
            cpu    = "250m"
            memory = "256Mi"
          }
        }
      }

      # ArgoCD 컨트롤러 설정
      controller = {
        serviceAccount = {
          create = false
          name   = kubernetes_service_account.argocd_application_controller.metadata[0].name
        }

        replicas = 1
        
        resources = {
          limits = {
            cpu    = "1000m"
            memory = "1Gi"
          }
          requests = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }

      # ArgoCD Repo Server 설정
      repoServer = {
        serviceAccount = {
          create = false
          name   = kubernetes_service_account.argocd_repo_server.metadata[0].name
        }

        replicas = 1
        
        resources = {
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
          requests = {
            cpu    = "250m"
            memory = "256Mi"
          }
        }
      }

      # Redis 설정
      redis = {
        resources = {
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
      }

      # ArgoCD 설정 (정확한 admin123! 해시)
      configs = {
        secret = {
          # 🔧 실제 생성된 해시 값으로 업데이트
          argocdServerAdminPassword = "$2y$05$IZWP9eSNwRQFbP2OocU9mOyI6PfUKdnj7oX25gIGbIrzGMv6ctn6e"  # admin123!
          argocdServerAdminPasswordMtime = "2023-01-01T00:00:00Z"
        }

        rbac = {
          "policy.default" = "role:readonly"
          "policy.csv" = <<-EOT
            p, role:admin, applications, *, */*, allow
            p, role:admin, clusters, *, *, allow
            p, role:admin, repositories, *, *, allow
            g, argocd-admins, role:admin
          EOT
        }
      }
    })
  ]

  timeout = 600

  depends_on = [
    kubernetes_namespace.argocd,
    kubernetes_service_account.argocd_server,
    kubernetes_service_account.argocd_application_controller,
    kubernetes_service_account.argocd_repo_server,
    aws_iam_role_policy.argocd_server_policy,
    aws_iam_role_policy.argocd_controller_policy,
    aws_iam_role_policy.argocd_repo_server_policy,
    kubernetes_persistent_volume_claim.argocd_server
  ]
}

# 애플리케이션용 네임스페이스 생성
resource "kubernetes_namespace" "pumati" {
  metadata {
    name = "pumati"
    
    labels = {
      name = "pumati"
      "app.kubernetes.io/name"      = "pumati"
      "app.kubernetes.io/component" = "pumati"
      "app.kubernetes.io/part-of"   = "pumati"
    }
  }
}

# ArgoCD Application - 백엔드 배포
resource "kubectl_manifest" "pumati_backend_application" {
  yaml_body = <<-EOT
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: pumati-backend
  namespace: ${kubernetes_namespace.argocd.metadata[0].name}
  labels:
    app.kubernetes.io/name: pumati-backend
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: pumati
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  
  source:
    repoURL: https://github.com/100-hours-a-week/8-pumati-cloud.git
    targetRevision: jacky
    path: aws/dev/gitops/helm/backend
    
    helm:
      valueFiles:
        - values.yaml
      values: |
        nodeSelector:
          node-type: system
        
  destination:
    server: https://kubernetes.default.svc
    namespace: ${kubernetes_namespace.pumati.metadata[0].name}
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
      - ApplyOutOfSyncOnly=true
    
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas
    - group: ""
      kind: Service
      jsonPointers:
        - /spec/clusterIP
EOT

  # kubectl 설정
  force_conflicts   = true
  server_side_apply = true
  
  # ArgoCD가 완전히 설치된 후에 Application 생성
  depends_on = [
    helm_release.argocd,
    kubernetes_namespace.pumati
  ]
}

# ArgoCD Application - 프론트엔드 배포 (새로 추가)
resource "kubectl_manifest" "pumati_frontend_application" {
  yaml_body = <<-EOT
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: pumati-frontend
  namespace: ${kubernetes_namespace.argocd.metadata[0].name}
  labels:
    app.kubernetes.io/name: pumati-frontend
    app.kubernetes.io/component: frontend
    app.kubernetes.io/part-of: pumati
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  
  source:
    repoURL: https://github.com/100-hours-a-week/8-pumati-cloud.git
    targetRevision: jacky
    path: aws/dev/gitops/helm/frontend
    
    helm:
      valueFiles:
        - values.yaml
      values: |
        nodeSelector:
          node-type: system
        
  destination:
    server: https://kubernetes.default.svc
    namespace: ${kubernetes_namespace.pumati.metadata[0].name}
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
      - ApplyOutOfSyncOnly=true
    
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas
    - group: ""
      kind: Service
      jsonPointers:
        - /spec/clusterIP
EOT

  # kubectl 설정
  force_conflicts   = true
  server_side_apply = true
  
  # ArgoCD가 완전히 설치된 후에 Application 생성
  depends_on = [
    helm_release.argocd,
    kubernetes_namespace.pumati
  ]
}
