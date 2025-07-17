#==============================================================================
# 09-workloads (Production Environment)
#==============================================================================

# 🎯 Production 워크로드 아키텍처 개요:
# 안정적이고 단순한 온디멘드 기반 EKS 클러스터 워크로드 관리
# - 단일 EKS 관리형 노드 그룹으로 운영 복잡도 최소화
# - 모든 컴포넌트의 고가용성 확보 (2개 레플리카)
# - Karpenter 미사용으로 예측 가능한 운영 환경 구축
# - 스팟 인스턴스 미사용으로 서비스 안정성 보장

# 📋 목차:
# 1. Cluster Autoscaler      (노드 자동 스케일링 관리)
# 2. AWS Load Balancer Controller (ALB/NLB 자동 프로비저닝)
# 3. External DNS            (Route53 DNS 레코드 자동 관리)
# 4. Metrics Server          (리소스 메트릭 수집 및 HPA 지원)
# 5. 네트워크 정책            (CoreDNS 접근 허용)
# 6. 보안 그룹 규칙          (노드 간 DNS 통신 허용)
# 7. aws-auth ConfigMap      (노드 클러스터 조인 권한 관리)

#==============================================================================
# 1. Cluster Autoscaler (노드 자동 스케일링 관리)
#==============================================================================

# 🎯 사용 목적:
# • EKS 관리형 노드 그룹의 자동 스케일링 담당
# • Pod 스케줄링 실패 시 노드를 자동으로 추가
# • 미사용 노드 감지 시 자동으로 제거하여 비용 최적화
# • 프로덕션 환경에서 안정적인 리소스 관리 보장

# 🔧 작동 원리:
# 1. Kubernetes Scheduler가 Pod 배치 실패를 감지
# 2. Cluster Autoscaler가 리소스 부족 상황 파악
# 3. Auto Scaling Group을 통해 새로운 노드 추가 요청
# 4. 새 노드가 클러스터에 조인되어 Pod 스케줄링 재시도
# 5. 미사용 노드 10분 후 자동 제거 (비용 절약)

#------------------------------------------------------------------------------
# 1-1. Cluster Autoscaler IAM 역할 생성
#------------------------------------------------------------------------------
# 🎯 역할: Auto Scaling Group 조작 권한을 가진 IAM 역할
# • IRSA(IAM Roles for Service Accounts) 방식으로 Pod에 권한 부여
# • EC2 Auto Scaling Group의 desired capacity 조정 권한
# • 보안: 특정 ServiceAccount만 이 역할을 사용 가능
resource "aws_iam_role" "cluster_autoscaler_role" {
  name = "${local.project_name}-${local.environment}-cluster-autoscaler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(local.cluster_oidc_issuer_url, "https://", "")}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(local.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:cluster-autoscaler"
            "${replace(local.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-cluster-autoscaler-role"
    Component = "Cluster-Autoscaler"
  })
}

#------------------------------------------------------------------------------
# 1-2. Cluster Autoscaler IAM 정책 연결
#------------------------------------------------------------------------------
# 🎯 역할: Auto Scaling Group 관리를 위한 최소 권한 정책
# • EC2 Auto Scaling Group 조회 및 조작
# • 노드 추가/제거 시 필요한 메타데이터 접근
# • 보안 원칙: 최소 권한 부여 (Principle of Least Privilege)
resource "aws_iam_role_policy" "cluster_autoscaler_policy" {
  name = "${local.project_name}-${local.environment}-cluster-autoscaler-policy"
  role = aws_iam_role.cluster_autoscaler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # Auto Scaling Group 관리 (EKS 관리형 노드 그룹)
          "autoscaling:DescribeAutoScalingGroups",      # ASG 목록 조회
          "autoscaling:DescribeAutoScalingInstances",   # ASG 인스턴스 상태 조회
          "autoscaling:DescribeLaunchConfigurations",   # 런치 설정 조회
          "autoscaling:DescribeTags",                   # ASG 태그 조회 (자동 검색용)
          "autoscaling:SetDesiredCapacity",             # 원하는 용량 설정 (핵심 권한)
          "autoscaling:TerminateInstanceInAutoScalingGroup", # 인스턴스 종료
          # EC2 인스턴스 정보 조회 (최적 인스턴스 타입 결정용)
          "ec2:DescribeLaunchTemplateVersions",         # 런치 템플릿 조회
          "ec2:DescribeInstanceTypes"                   # 인스턴스 타입 정보 조회
        ]
        Resource = "*"
      }
    ]
  })
}

#------------------------------------------------------------------------------
# 1-3. Cluster Autoscaler Helm 차트 설치
#------------------------------------------------------------------------------
# 🎯 역할: Kubernetes 클러스터 내에서 실행되는 오토스케일러 컨트롤러
# • Kubernetes API를 통해 Pod 스케줄링 상태 모니터링
# • AWS API를 통해 Auto Scaling Group 조작
# • 프로덕션 환경: 2개 레플리카로 고가용성 확보
resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "9.37.0"  # 안정적인 버전
  namespace  = "kube-system"

  # 클러스터 식별 설정
  set {
    name  = "autoDiscovery.clusterName"
    value = local.cluster_name
  }

  set {
    name  = "awsRegion"
    value = local.region
  }

  # ServiceAccount 및 IRSA 설정
  set {
    name  = "rbac.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "rbac.serviceAccount.name"
    value = "cluster-autoscaler"
  }

  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.cluster_autoscaler_role.arn
  }

  # 리소스 제한 (프로덕션 환경용)
  set {
    name  = "resources.requests.cpu"
    value = "100m"    # 기본 CPU 요구량
  }

  set {
    name  = "resources.requests.memory"
    value = "300Mi"   # 기본 메모리 요구량
  }

  set {
    name  = "resources.limits.cpu"
    value = "200m"    # 최대 CPU 사용량 (dev 대비 2배)
  }

  set {
    name  = "resources.limits.memory"
    value = "500Mi"   # 최대 메모리 사용량 (dev 대비 1.67배)
  }

  # 스케일링 동작 설정 (프로덕션 환경 최적화)
  set {
    name  = "extraArgs.scale-down-delay-after-add"
    value = "10m"     # 노드 추가 후 10분 대기 (성급한 제거 방지)
  }

  set {
    name  = "extraArgs.scale-down-unneeded-time"
    value = "10m"     # 미사용 노드 10분 후 제거 (비용 최적화)
  }

  set {
    name  = "extraArgs.skip-nodes-with-local-storage"
    value = "false"   # 로컬 스토리지 노드도 제거 허용
  }

  set {
    name  = "extraArgs.skip-nodes-with-system-pods"
    value = "false"   # 시스템 Pod가 있는 노드도 제거 허용
  }

  # 자동 검색 설정 (태그 기반으로 관리할 ASG 자동 탐지)
  set {
    name  = "extraArgs.node-group-auto-discovery"
    value = "asg:tag=k8s.io/cluster-autoscaler/enabled=true,k8s.io/cluster-autoscaler/${local.cluster_name}=owned"
  }

  # 고가용성 설정 (프로덕션 환경 필수)
  set {
    name  = "replicaCount"
    value = "2"       # 2개 레플리카로 단일 장애점 제거
  }

  depends_on = [
    aws_iam_role.cluster_autoscaler_role,
    aws_iam_role_policy.cluster_autoscaler_policy
  ]
}

#==============================================================================
# 2. AWS Load Balancer Controller (ALB/NLB 자동 프로비저닝)
#==============================================================================

# 🎯 사용 목적:
# • Kubernetes Ingress 리소스를 AWS ALB(Application Load Balancer)로 자동 변환
# • Service 리소스를 AWS NLB(Network Load Balancer)로 자동 변환  
# • SSL/TLS 인증서 자동 연결 및 도메인 기반 라우팅 구현
# • 외부 트래픽을 클러스터 내부 서비스로 라우팅하는 관문 역할

# 🔧 작동 원리:
# 1. Kubernetes API에서 Ingress/Service 리소스 변화 감지
# 2. AWS API를 통해 ALB/NLB 자동 생성 및 구성
# 3. Target Group 생성 및 Pod IP를 자동 등록/해제
# 4. 보안 그룹, 서브넷, SSL 인증서 자동 연결
# 5. Ingress 삭제 시 관련 AWS 리소스 자동 정리

#------------------------------------------------------------------------------
# 2-1. AWS Load Balancer Controller IAM 역할 생성
#------------------------------------------------------------------------------
# 🎯 역할: AWS 로드밸런서 및 관련 리소스 관리 권한을 가진 IAM 역할
# • ALB/NLB 생성, 수정, 삭제 권한
# • Target Group 관리 및 타겟 등록/해제
# • 보안 그룹 생성 및 규칙 관리 (동적 보안 그룹 생성)
resource "aws_iam_role" "aws_load_balancer_controller_role" {
  name = "${local.project_name}-${local.environment}-aws-load-balancer-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(local.cluster_oidc_issuer_url, "https://", "")}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(local.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
            "${replace(local.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-aws-load-balancer-controller-role"
      Component = "LoadBalancer-Controller"
    }
  )
}

#------------------------------------------------------------------------------
# 2-2. AWS Load Balancer Controller 공식 IAM 정책
#------------------------------------------------------------------------------
# 🎯 역할: AWS 공식 정책으로 로드밸런서 관련 모든 권한 포함
# • Elastic Load Balancing 모든 작업 (생성, 수정, 삭제, 조회)
# • EC2 보안 그룹 생성 및 관리 (동적 보안 그룹)
# • Certificate Manager 인증서 조회 및 연결
# • WAF 연결 및 Shield 보호 설정
resource "aws_iam_policy" "aws_load_balancer_controller_policy" {
  name        = "${local.project_name}-${local.environment}-AWSLoadBalancerControllerIAMPolicy"
  description = "IAM policy for AWS Load Balancer Controller (Official)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:CreateServiceLinkedRole"  # ELB 서비스 링크 역할 생성
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = "elasticloadbalancing.amazonaws.com"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          # EC2 리소스 조회 (VPC, 서브넷, 보안그룹 정보)
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses", 
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcPeeringConnections",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeTags",
          "ec2:GetCoipPoolUsage",
          "ec2:GetManagedPrefixListEntries",
          "ec2:DescribeCoipPools",
          # 로드밸런서 조회 작업
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeListenerCertificates",
          "elasticloadbalancing:DescribeSSLPolicies",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          # 인증서 및 보안 서비스 조회
          "cognito-idp:DescribeUserPoolClient",   # Cognito 인증
          "acm:ListCertificates",                 # SSL 인증서 목록
          "acm:DescribeCertificate",              # SSL 인증서 세부정보
          "iam:ListServerCertificates",           # IAM 인증서 목록
          "iam:GetServerCertificate",             # IAM 인증서 조회
          # WAF 연결 관리
          "waf-regional:GetWebACL",
          "waf-regional:GetWebACLForResource", 
          "waf-regional:AssociateWebACL",
          "waf-regional:DisassociateWebACL",
          "wafv2:GetWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL",
          # Shield 보호 관리
          "shield:DescribeProtection",
          "shield:GetSubscriptionState",
          "shield:DescribeSubscription",
          "shield:CreateProtection",
          "shield:DeleteProtection"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          # 보안 그룹 관리 (동적 보안 그룹 생성)
          "ec2:AuthorizeSecurityGroupIngress",    # 인바운드 규칙 추가
          "ec2:RevokeSecurityGroupIngress",       # 인바운드 규칙 제거
          "ec2:CreateSecurityGroup"               # 보안 그룹 생성
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags"  # 보안 그룹 태그 생성
        ]
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          StringEquals = {
            "ec2:CreateAction" = "CreateSecurityGroup"
          }
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "true"
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress", 
          "ec2:DeleteSecurityGroup"
        ]
        Resource = "*"
        Condition = {
          Null = {
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup"
        ]
        Resource = "*"
        Condition = {
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          # 로드밸런서 관리 (전체 라이프사이클)
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeListenerCertificates",
          "elasticloadbalancing:CreateRule",
          "elasticloadbalancing:DeleteRule",
          "elasticloadbalancing:ModifyRule",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          # 타겟 그룹 관리
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:RegisterTargets",      # Pod IP 등록
          "elasticloadbalancing:DeregisterTargets",    # Pod IP 해제
          # 기타 관리 작업
          "elasticloadbalancing:DescribeSSLPolicies",
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags",
          "elasticloadbalancing:DescribeTags",
          "elasticloadbalancing:SetIpAddressType",
          "elasticloadbalancing:SetSecurityGroups",
          "elasticloadbalancing:SetSubnets"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:AddTags"
        ]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
        ]
        Condition = {
          StringEquals = {
            "elasticloadbalancing:CreateAction" = [
              "CreateTargetGroup",
              "CreateLoadBalancer"
            ]
          }
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:RegisterTargets",    # 핵심: Pod를 타겟으로 등록
          "elasticloadbalancing:DeregisterTargets"   # 핵심: Pod를 타겟에서 제거
        ]
        Resource = "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-AWSLoadBalancerControllerIAMPolicy"
      Component = "LoadBalancer-Controller"
    }
  )
}

# 정책을 역할에 연결
resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller_policy" {
  policy_arn = aws_iam_policy.aws_load_balancer_controller_policy.arn
  role       = aws_iam_role.aws_load_balancer_controller_role.name
}

#------------------------------------------------------------------------------
# 2-3. AWS Load Balancer Controller Helm 차트 설치
#------------------------------------------------------------------------------
# 🎯 역할: Kubernetes 클러스터 내에서 실행되는 로드밸런서 컨트롤러
# • Ingress 리소스 변화를 실시간 감지
# • AWS API를 통해 ALB/NLB 자동 생성 및 관리
# • 프로덕션 환경: 2개 레플리카로 고가용성 및 처리량 확보
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.8.1"  # 최신 안정 버전
  namespace  = "kube-system"

  # 클러스터 식별 설정
  set {
    name  = "clusterName"
    value = local.cluster_name
  }

  # ServiceAccount 및 IRSA 설정
  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.aws_load_balancer_controller_role.arn
  }

  # 리소스 제한 (프로덕션 환경용 - dev 대비 2.5배)
  set {
    name  = "resources.limits.cpu"
    value = "500m"    # 높은 CPU (ALB 생성 작업 집약적)
  }

  set {
    name  = "resources.limits.memory"
    value = "1Gi"     # 충분한 메모리 (다수 리소스 캐싱)
  }

  set {
    name  = "resources.requests.cpu"
    value = "200m"    # 기본 CPU 요구량
  }

  set {
    name  = "resources.requests.memory"
    value = "512Mi"   # 기본 메모리 요구량
  }

  # 고가용성을 위한 레플리카 설정 (프로덕션 필수)
  set {
    name  = "replicaCount"
    value = "2"       # 2개 레플리카로 로드밸런서 생성 작업 분산
  }

  depends_on = [
    aws_iam_role_policy_attachment.aws_load_balancer_controller_policy,
    helm_release.cluster_autoscaler
  ]
}

#==============================================================================
# 3. External DNS (Route53 DNS 레코드 자동 관리)
#==============================================================================

# 🎯 사용 목적:
# • Kubernetes Ingress의 host 설정을 기반으로 Route53 DNS A 레코드 자동 생성
# • LoadBalancer Service의 외부 도메인을 Route53에 자동 등록
# • Ingress 삭제 시 해당 DNS 레코드 자동 정리 (upsert-only 모드에서는 생성만)
# • 도메인 기반 서비스 접근을 위한 DNS 자동화

# 🔧 작동 원리:
# 1. Kubernetes API에서 Ingress/Service 리소스의 변화 감지
# 2. external-dns.alpha.kubernetes.io/hostname 어노테이션 읽기
# 3. ALB의 DNS 이름을 조회하여 CNAME 또는 A 레코드 생성
# 4. Route53 API를 통해 DNS 레코드 생성/업데이트
# 5. TTL 및 기타 DNS 설정 자동 관리

#------------------------------------------------------------------------------
# 3-1. External DNS IAM 역할 생성
#------------------------------------------------------------------------------
# 🎯 역할: Route53 호스팅 존 및 DNS 레코드 관리 권한을 가진 IAM 역할
# • Route53 호스팅 존 조회 권한
# • DNS 레코드 생성, 수정, 삭제 권한 (ChangeResourceRecordSets)
# • 도메인 필터링을 통한 보안 (특정 도메인만 관리)
resource "aws_iam_role" "external_dns_role" {
  name = "${local.project_name}-${local.environment}-external-dns"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(local.cluster_oidc_issuer_url, "https://", "")}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(local.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:external-dns"
            "${replace(local.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-external-dns-role"
      Component = "External-DNS"
    }
  )
}

#------------------------------------------------------------------------------
# 3-2. External DNS Route53 정책
#------------------------------------------------------------------------------
# 🎯 역할: Route53 DNS 관리를 위한 최소 권한 정책
# • 호스팅 존 목록 조회 (도메인 필터링용)
# • DNS 레코드 변경 세트 생성 및 실행
# • 변경 상태 추적 및 확인
resource "aws_iam_role_policy" "external_dns_policy" {
  name = "${local.project_name}-${local.environment}-external-dns-policy"
  role = aws_iam_role.external_dns_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # Route53 DNS 레코드 관리 권한
          "route53:ChangeResourceRecordSets",    # DNS 레코드 생성/수정/삭제 (핵심)
          "route53:ListResourceRecordSets",      # 기존 레코드 조회
          "route53:GetChange"                    # 변경 상태 확인
        ]
        Resource = "arn:aws:route53:::hostedzone/*"  # 모든 호스팅 존에 대한 권한
      },
      {
        Effect = "Allow"
        Action = [
          # Route53 호스팅 존 조회 권한
          "route53:ListHostedZones",             # 호스팅 존 목록 조회
          "route53:ListResourceRecordSets"       # 레코드 목록 조회
        ]
        Resource = "*"
      }
    ]
  })
}

#------------------------------------------------------------------------------
# 3-3. External DNS Helm 차트 설치
#------------------------------------------------------------------------------
# 🎯 역할: Kubernetes 클러스터 내에서 실행되는 DNS 관리 컨트롤러
# • Ingress 및 Service 리소스 실시간 모니터링
# • Route53 API를 통한 DNS 레코드 자동 관리
# • 프로덕션 환경: 2개 레플리카로 DNS 관리 작업 분산
resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = "1.14.3"  # 최신 안정 버전
  namespace  = "kube-system"

  # AWS Route53 제공자 설정
  set {
    name  = "provider"
    value = "aws"
  }

  set {
    name  = "aws.region"
    value = local.region
  }

  # 도메인 필터 설정 (보안: 특정 도메인만 관리)
  set {
    name  = "domainFilters[0]"
    value = "tebutebu.com"  # 상위 도메인으로 설정하여 모든 서브도메인 포함
  }

  # 정책 설정 (안전 모드: 생성만, 삭제 방지)
  set {
    name  = "policy"
    value = "upsert-only"  # DNS 레코드 생성/업데이트만, 삭제는 수동
  }

  # 모니터링 소스 설정
  set {
    name  = "sources[0]"
    value = "ingress"     # Ingress 리소스 모니터링
  }

  set {
    name  = "sources[1]"
    value = "service"     # LoadBalancer Service 모니터링
  }

  # ServiceAccount 및 IRSA 설정
  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "external-dns"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.external_dns_role.arn
  }

  # 리소스 제한 (프로덕션 환경용 - dev 대비 2배)
  set {
    name  = "resources.limits.cpu"
    value = "200m"    # DNS 조회 작업용 충분한 CPU
  }

  set {
    name  = "resources.limits.memory"
    value = "256Mi"   # DNS 레코드 캐싱용 메모리
  }

  set {
    name  = "resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "resources.requests.memory"
    value = "128Mi"
  }

  # 로그 설정
  set {
    name  = "logLevel"
    value = "info"    # 운영 환경에 적합한 로그 레벨
  }

  # DNS 레코드 소유권 표시 (충돌 방지)
  set {
    name  = "txtOwnerId"
    value = "${local.project_name}-${local.environment}"
  }

  # 실제 DNS 레코드 생성 모드
  set {
    name  = "dryRun"
    value = "false"   # 실제 DNS 레코드 생성
  }

  # 고가용성 설정 (프로덕션 환경)
  set {
    name  = "replicas"
    value = "2"       # 2개 레플리카로 DNS 관리 작업 분산
  }

  depends_on = [
    aws_iam_role.external_dns_role,
    helm_release.aws_load_balancer_controller
  ]
}

#==============================================================================
# 4. Metrics Server (리소스 메트릭 수집 및 HPA 지원)
#==============================================================================

# 🎯 사용 목적:
# • Kubernetes 클러스터 내 Pod 및 Node의 CPU/Memory 사용량 실시간 수집
# • kubectl top nodes/pods 명령어 지원
# • Horizontal Pod Autoscaler (HPA) 동작을 위한 메트릭 제공
# • Vertical Pod Autoscaler (VPA) 권장사항 계산을 위한 데이터 수집
# • 클러스터 리소스 모니터링 및 용량 계획 수립 지원

# 🔧 작동 원리:
# 1. kubelet의 /metrics/resource 엔드포인트에서 메트릭 수집
# 2. 수집된 데이터를 metrics.k8s.io API로 제공
# 3. HPA Controller가 이 API를 통해 스케일링 결정
# 4. kubectl top 명령어가 이 API를 통해 사용량 표시
# 5. 15초마다 메트릭 업데이트 (기본값)

#------------------------------------------------------------------------------
# 4-1. Metrics Server Helm 차트 설치
#------------------------------------------------------------------------------
# 🎯 역할: Kubernetes 클러스터 내에서 실행되는 메트릭 수집 서버
# • 시스템 컴포넌트로서 높은 우선순위 설정
# • 프로덕션 환경: 2개 레플리카로 고가용성 및 메트릭 수집 안정성 확보
# • Pod Disruption Budget 활성화로 무중단 메트릭 수집 보장
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.12.0"  # 안정적인 최신 버전
  namespace  = "kube-system"

  # 리소스 제한 (프로덕션 환경용 - dev 대비 2배)
  set {
    name  = "resources.limits.cpu"
    value = "200m"    # 메트릭 수집 처리용 충분한 CPU
  }

  set {
    name  = "resources.limits.memory"
    value = "256Mi"   # 메트릭 데이터 버퍼링용 메모리
  }

  set {
    name  = "resources.requests.cpu"
    value = "100m"    # 기본 CPU 요구량
  }

  set {
    name  = "resources.requests.memory"
    value = "128Mi"   # 기본 메모리 요구량
  }

  # 고가용성 설정 (프로덕션 환경 필수)
  set {
    name  = "replicas"
    value = "2"       # 2개 레플리카로 메트릭 수집 중단 방지
  }

  # Pod 우선순위 설정 (시스템 중요 컴포넌트)
  set {
    name  = "priorityClassName"
    value = "system-cluster-critical"  # 최고 우선순위로 스케줄링 보장
  }

  # 보안 컨텍스트 설정 (보안 강화)
  set {
    name  = "securityContext.allowPrivilegeEscalation"
    value = "false"   # 권한 에스컬레이션 방지
  }

  set {
    name  = "securityContext.readOnlyRootFilesystem"
    value = "true"    # 읽기 전용 루트 파일시스템
  }

  set {
    name  = "securityContext.runAsNonRoot"
    value = "true"    # 비특권 사용자로 실행
  }

  set {
    name  = "securityContext.runAsUser"
    value = "1000"    # 특정 사용자 ID로 실행
  }

  # 서비스 설정
  set {
    name  = "service.type"
    value = "ClusterIP"  # 클러스터 내부 접근만
  }

  set {
    name  = "service.port"
    value = "443"        # HTTPS 포트
  }

  # 업데이트 전략
  set {
    name  = "updateStrategy.type"
    value = "RollingUpdate"  # 무중단 업데이트
  }

  # Pod Disruption Budget 설정 (프로덕션 필수)
  set {
    name  = "podDisruptionBudget.enabled"
    value = "true"    # 프로덕션 환경에서는 PDB 활성화
  }

  set {
    name  = "podDisruptionBudget.minAvailable"
    value = "1"       # 최소 1개는 항상 실행 (메트릭 수집 중단 방지)
  }

  depends_on = [
    helm_release.external_dns
  ]
}

#==============================================================================
# 5. 네트워크 정책 (CoreDNS 접근 허용)
#==============================================================================

# 🎯 사용 목적:
# • 클러스터 내 모든 Pod가 DNS 쿼리를 수행할 수 있도록 네트워크 정책 설정
# • 특히 단일 노드그룹 환경에서 DNS 해석 문제 방지
# • 애플리케이션 Pod가 외부 API (예: 카카오 로그인) 호출 시 도메인 해석 보장
# • 네트워크 정책이 있는 환경에서 CoreDNS 접근 명시적 허용

# 🔧 작동 원리:
# 1. kube-system 네임스페이스의 CoreDNS Pod를 대상으로 정책 적용
# 2. 모든 네임스페이스에서 오는 DNS 쿼리 트래픽 허용
# 3. UDP/53 및 TCP/53 포트로의 접근 명시적 허용
# 4. DNS 쿼리 실패로 인한 애플리케이션 오류 방지

#------------------------------------------------------------------------------
# 5-1. CoreDNS 접근 허용 네트워크 정책
#------------------------------------------------------------------------------
# 🎯 역할: DNS 쿼리 트래픽을 위한 네트워크 정책
# • 모든 Pod → CoreDNS 통신 허용
# • DNS 프로토콜 포트 (UDP/53, TCP/53) 명시적 허용
# • 네트워크 격리 환경에서 DNS 서비스 가용성 보장
resource "kubectl_manifest" "allow_dns_access_to_coredns" {
  yaml_body = <<-EOT
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-traffic-to-coredns
  namespace: kube-system
spec:
  # 정책 적용 대상: CoreDNS Pod 선택
  podSelector:
    matchLabels:
      k8s-app: kube-dns  # CoreDNS Pod의 표준 레이블
  policyTypes:
    - Ingress  # 인바운드 트래픽 정책만 정의
  ingress:
    # 모든 네임스페이스의 Pod에서 오는 트래픽 허용
    - from:
        - namespaceSelector: {}  # 모든 네임스페이스 허용
      # DNS 프로토콜 포트 허용
      ports:
        - protocol: UDP
          port: 53    # DNS 쿼리 (주로 사용)
        - protocol: TCP  
          port: 53    # DNS 쿼리 (큰 응답 시 사용)
EOT

  depends_on = [
    helm_release.metrics_server
  ]
}

#==============================================================================
# 6. 보안 그룹 규칙 (노드 간 DNS 통신 허용)
#==============================================================================

# 🎯 사용 목적:
# • AWS 보안 그룹 수준에서 노드 간 DNS 통신 명시적 허용
# • 단일 노드그룹 환경에서 모든 노드가 동일한 보안 그룹을 공유
# • CoreDNS Pod와 애플리케이션 Pod 간 네트워크 통신 보장
# • Kubernetes 네트워크 정책과 AWS 보안 그룹의 이중 보안 해제

# 🔧 작동 원리:
# 1. EKS 노드 보안 그룹 내에서 자기 자신으로부터의 DNS 트래픽 허용
# 2. UDP/53 및 TCP/53 포트에 대한 인바운드 규칙 추가
# 3. 노드 A의 Pod → 노드 B의 CoreDNS Pod 통신 허용
# 4. AWS 보안 그룹 수준의 DNS 통신 차단 해제

#------------------------------------------------------------------------------
# 6-1. DNS UDP 트래픽 허용 보안 그룹 규칙
#------------------------------------------------------------------------------
# 🎯 역할: 동일 보안 그룹 내에서 DNS UDP 트래픽 허용
# • 일반적인 DNS 쿼리 (UDP/53) 허용
# • 빠른 DNS 응답을 위한 UDP 프로토콜 지원
resource "aws_security_group_rule" "allow_dns_ingress_udp_from_self" {
  type                     = "ingress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "udp"
  source_security_group_id = local.eks_node_sg_id  # 같은 보안 그룹에서 오는 트래픽
  security_group_id        = local.eks_node_sg_id  # 대상 보안 그룹
  description              = "Allow Ingress DNS (UDP) from other nodes in the same SG (for CoreDNS)"
}

#------------------------------------------------------------------------------
# 6-2. DNS TCP 트래픽 허용 보안 그룹 규칙
#------------------------------------------------------------------------------
# 🎯 역할: 동일 보안 그룹 내에서 DNS TCP 트래픽 허용
# • 큰 DNS 응답 (TCP/53) 허용
# • 복잡한 DNS 쿼리 및 Zone Transfer 지원
resource "aws_security_group_rule" "allow_dns_ingress_tcp_from_self" {
  type                     = "ingress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "tcp"
  source_security_group_id = local.eks_node_sg_id  # 같은 보안 그룹에서 오는 트래픽
  security_group_id        = local.eks_node_sg_id  # 대상 보안 그룹
  description              = "Allow Ingress DNS (TCP) from other nodes in the same SG (for CoreDNS)"
}

#==============================================================================
# 7. aws-auth ConfigMap (노드 클러스터 조인 권한 관리)
#==============================================================================

# 🎯 사용 목적:
# • EKS 관리형 노드 그룹이 Kubernetes 클러스터에 조인할 수 있도록 IAM 역할 매핑
# • 노드의 kubelet이 Kubernetes API 서버에 인증할 수 있도록 권한 부여
# • 프로덕션 환경: 단일 노드그룹만 사용하므로 단순한 역할 매핑
# • 노드 자동 등록 및 워크로드 스케줄링 허용

# 🔧 작동 원리:
# 1. EKS 노드 그룹의 인스턴스가 부팅될 때 Instance Profile의 역할 사용
# 2. aws-auth ConfigMap에서 해당 역할을 Kubernetes 사용자/그룹으로 매핑
# 3. 매핑된 그룹 권한으로 노드가 클러스터에 조인
# 4. system:bootstrappers - 노드 부트스트랩 권한
# 5. system:nodes - 노드 운영 권한

#------------------------------------------------------------------------------
# 7-1. EKS 노드 그룹 역할 매핑 ConfigMap
#------------------------------------------------------------------------------
# 🎯 역할: 단일 EKS 관리형 노드 그룹을 위한 IAM 역할 매핑
# • 오직 EKS 관리형 노드 그룹 역할만 등록 (Karpenter 역할 제외)
# • 단순한 권한 구조로 운영 복잡도 최소화
# • 표준 Kubernetes 노드 권한 부여
resource "kubernetes_config_map_v1_data" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode([
      # EKS 관리형 노드 그룹 역할만 등록 (단일 노드그룹 환경)
      {
        rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.project_name}-${local.environment}-eks-node-group-role"
        username = "system:node:{{EC2PrivateDNSName}}"  # 노드별 고유 사용자명
        groups = [
          "system:bootstrappers",  # 노드 부트스트랩 권한
          "system:nodes"          # 노드 운영 권한
        ]
      }
      # ❌ Karpenter 노드 역할 제거됨 (프로덕션 단순화)
    ])
  }

  # ConfigMap 업데이트 시 강제 적용 (기존 설정 덮어쓰기)
  force = true

  depends_on = [
    kubectl_manifest.allow_dns_access_to_coredns
  ]
}

# 🎯 Production 워크로드 배포 완료!
# 
# 배포된 컴포넌트 요약:
# ✅ 1. Cluster Autoscaler      (2 replicas) - 노드 자동 스케일링
# ✅ 2. AWS Load Balancer Controller (2 replicas) - ALB/NLB 관리  
# ✅ 3. External DNS           (2 replicas) - Route53 DNS 관리
# ✅ 4. Metrics Server         (2 replicas) - 리소스 메트릭 수집
# ✅ 5. 네트워크 정책          - CoreDNS 접근 허용
# ✅ 6. 보안 그룹 규칙         - 노드 간 DNS 통신 허용  
# ✅ 7. aws-auth ConfigMap     - 노드 클러스터 조인 권한
#
# 제외된 컴포넌트 (dev 대비):
# ❌ AWS Node Termination Handler (온디멘드 전용으로 불필요)
# ❌ Karpenter (모든 구성요소)     (단일 노드그룹으로 단순화)
#
# 아키텍처 특징:
# 🏗️  단일 EKS 관리형 온디멘드 노드 그룹
# 🔒  모든 컴포넌트 2개 레플리카 (고가용성)
# 🚀  프로덕션 최적화된 리소스 할당
# ⚡  단순하고 예측 가능한 운영 환경
