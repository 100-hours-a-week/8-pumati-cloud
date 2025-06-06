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

# ArgoCD 서버용 IAM 역할 생성
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
            "${replace(data.terraform_remote_state.eks.outputs.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:argocd:argocd-server"
            "${replace(data.terraform_remote_state.eks.outputs.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# ArgoCD 서버용 IAM 정책 연결 (필요한 경우 추가 권한 부여)
resource "aws_iam_role_policy" "argocd_server_policy" {
  name = "${local.project_name}-${local.environment}-argocd-server-policy"
  role = aws_iam_role.argocd_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      }
    ]
  })
}

# ArgoCD Helm 차트 설치
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "5.51.6"  # 안정적인 버전 사용
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  # ArgoCD 서버 설정
  values = [
    yamlencode({
      # 글로벌 설정
      global = {
        domain = "argocd.${local.domain_name}"
        
        # 🎯 모든 ArgoCD 컴포넌트를 시스템 노드에 배치
        nodeSelector = {
          "node-type" = "system"
        }
        
        # 🔧 시스템 노드의 taint를 허용하는 톨러레이션 (필요시 활성화)
        # tolerations = [
        #   {
        #     key      = "node-type"
        #     operator = "Equal"
        #     value    = "system"
        #     effect   = "NoSchedule"
        #   }
        # ]
      }

      # ArgoCD 서버 설정
      server = {
        # 서비스 계정 설정
        serviceAccount = {
          create = false
          name   = kubernetes_service_account.argocd_server.metadata[0].name
        }

        # 🎯 서버 전용 노드 선택자 (글로벌 설정 재정의)
        nodeSelector = {
          "node-type" = "system"
          "role"      = "system-component"
        }

        # 인그레스 설정
        ingress = {
          enabled = true
          ingressClassName = "nginx"
          annotations = {
            "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
            "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
            "nginx.ingress.kubernetes.io/backend-protocol" = "GRPC"
          }
          hosts = [
            {
              host = "argocd.${local.domain_name}"
              paths = [
                {
                  path = "/*"
                  pathType = "Prefix"
                }
              ]
            }
          ]
          tls = [
            {
              secretName = "argocd-server-tls"
              hosts = [
                "argocd.${local.domain_name}"
              ]
            }
          ]
        }

        # 추가 설정
        extraArgs = [
          "--insecure"  # 인그레스에서 TLS 종료하므로 내부는 insecure 모드
        ]

        # 🔧 리소스 제한 (시스템 노드 리소스 고려)
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

        # 🚀 고가용성을 위한 복제본 설정
        replicas = 2
        
        # 🔄 Pod 분산 배치 (Anti-Affinity)
        affinity = {
          podAntiAffinity = {
            preferredDuringSchedulingIgnoredDuringExecution = [
              {
                weight = 100
                podAffinityTerm = {
                  labelSelector = {
                    matchLabels = {
                      "app.kubernetes.io/name" = "argocd-server"
                    }
                  }
                  topologyKey = "kubernetes.io/hostname"
                }
              }
            ]
          }
        }
      }

      # ArgoCD 컨트롤러 설정
      controller = {
        # 🎯 컨트롤러도 시스템 노드에 배치
        nodeSelector = {
          "node-type" = "system"
          "role"      = "system-component"
        }
        
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

        # 🚀 컨트롤러 고가용성 설정
        replicas = 1  # 컨트롤러는 단일 인스턴스 권장 (리더 선출 복잡성 방지)
      }

      # ArgoCD Repo Server 설정
      repoServer = {
        # 🎯 Repo Server도 시스템 노드에 배치
        nodeSelector = {
          "node-type" = "system"
          "role"      = "system-component"
        }
        
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

        # 🚀 Repo Server 고가용성 설정
        replicas = 2
        
        # 🔄 Pod 분산 배치
        affinity = {
          podAntiAffinity = {
            preferredDuringSchedulingIgnoredDuringExecution = [
              {
                weight = 100
                podAffinityTerm = {
                  labelSelector = {
                    matchLabels = {
                      "app.kubernetes.io/name" = "argocd-repo-server"
                    }
                  }
                  topologyKey = "kubernetes.io/hostname"
                }
              }
            ]
          }
        }
      }

      # ArgoCD Redis 설정
      redis = {
        # 🎯 Redis도 시스템 노드에 배치
        nodeSelector = {
          "node-type" = "system"
          "role"      = "system-component"
        }
        
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

      # ArgoCD 설정
      configs = {
        # 초기 관리자 비밀번호 설정 (변경 필요)
        secret = {
          argocdServerAdminPassword = "$2a$10$rRyBsGSHK6.uc8fntPwVIuLVHgsAhAX7TcdrqW/RADU0uh7CaChLa"  # password
          argocdServerAdminPasswordMtime = "2023-01-01T00:00:00Z"
        }

        # 저장소 설정 (필요시 추가)
        repositories = {}

        # RBAC 설정
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

  # Helm 차트 설치 대기 시간 설정
  timeout = 600

  depends_on = [
    kubernetes_namespace.argocd,
    kubernetes_service_account.argocd_server
  ]
}

# ArgoCD CLI 접근을 위한 포트 포워딩 서비스 (선택사항)
resource "kubernetes_service" "argocd_server_nodeport" {
  metadata {
    name      = "argocd-server-nodeport"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  spec {
    type = "NodePort"
    
    port {
      name        = "server"
      port        = 80
      target_port = 8080
      node_port   = 30080
    }

    port {
      name        = "grpc"
      port        = 443
      target_port = 8080
      node_port   = 30443
    }

    selector = {
      "app.kubernetes.io/name" = "argocd-server"
    }
  }
}

# 프론트엔드 애플리케이션을 위한 ArgoCD Application
resource "kubectl_manifest" "argocd_frontend_app" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "pumati-frontend"
      namespace = kubernetes_namespace.argocd.metadata[0].name
      finalizers = [
        "resources-finalizer.argocd.argoproj.io"
      ]
    }
    spec = {
      project = "default"
      source = {
        # 로컬 Helm 차트 사용 (Git 저장소로 변경 가능)
        path           = "aws/dev/07-argocd/helm/frontend"
        repoURL        = "https://github.com/pumati/infrastructure"  # 실제 Git 저장소로 변경 필요
        targetRevision = "HEAD"
        helm = {
          valueFiles = ["values.yaml"]
          # Jenkins에서 이미지 태그를 동적으로 업데이트할 수 있도록 설정
          parameters = [
            {
              name  = "image.tag"
              value = "latest"
            },
            {
              name  = "ingress.hosts[0].host"
              value = "pumati.${local.domain_name}"
            },
            {
              name  = "ingress.tls[0].hosts[0]"
              value = "pumati.${local.domain_name}"
            }
          ]
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "pumati-frontend"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  })

  depends_on = [helm_release.argocd]
}

# 백엔드 애플리케이션을 위한 ArgoCD Application
resource "kubectl_manifest" "argocd_backend_app" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "pumati-backend"
      namespace = kubernetes_namespace.argocd.metadata[0].name
      finalizers = [
        "resources-finalizer.argocd.argoproj.io"
      ]
    }
    spec = {
      project = "default"
      source = {
        # 로컬 Helm 차트 사용 (Git 저장소로 변경 가능)
        path           = "aws/dev/07-argocd/helm/backend"
        repoURL        = "https://github.com/pumati/infrastructure"  # 실제 Git 저장소로 변경 필요
        targetRevision = "HEAD"
        helm = {
          valueFiles = ["values.yaml"]
          # Jenkins에서 이미지 태그를 동적으로 업데이트할 수 있도록 설정
          parameters = [
            {
              name  = "image.tag"
              value = "latest"
            },
            {
              name  = "ingress.hosts[0].host"
              value = "api.${local.domain_name}"
            },
            {
              name  = "ingress.tls[0].hosts[0]"
              value = "api.${local.domain_name}"
            },
            {
              name  = "env[2].value"  # DB_HOST
              value = data.terraform_remote_state.db.outputs.mysql_private_ip
            }
          ]
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "pumati-backend"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  })

  depends_on = [helm_release.argocd]
}

# Jenkins 웹훅을 위한 ArgoCD 설정
resource "kubectl_manifest" "argocd_webhook_config" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
      name      = "argocd-notifications-cm"
      namespace = kubernetes_namespace.argocd.metadata[0].name
      labels = {
        "app.kubernetes.io/name" = "argocd-notifications"
        "app.kubernetes.io/part-of" = "argocd"
      }
    }
    data = {
      # Jenkins 트리거를 위한 웹훅 설정
      "service.webhook.jenkins" = yamlencode({
        url = "http://jenkins.${local.domain_name}/generic-webhook-trigger/invoke"
        headers = [
          {
            name  = "Content-Type"
            value = "application/json"
          }
        ]
      })
      
      # 알림 템플릿 설정
      "template.app-deployed" = yamlencode({
        webhook = {
          jenkins = {
            method = "POST"
            body = jsonencode({
              app_name    = "{{.app.metadata.name}}"
              app_status  = "{{.app.status.sync.status}}"
              revision    = "{{.app.status.sync.revision}}"
              timestamp   = "{{.timestamp}}"
            })
          }
        }
      })
      
      # 트리거 설정
      "trigger.on-deployed" = yamlencode({
        - when = "app.status.sync.status == 'Synced'"
          send = ["app-deployed"]
      })
    }
  })

  depends_on = [helm_release.argocd]
}
