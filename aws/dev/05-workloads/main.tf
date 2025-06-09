#==============================================================================
# 05-workloads
#==============================================================================

# 🚀 AWS Node Termination Handler (스팟 인스턴스 안전 종료)
# 🚀 Cluster Autoscaler (EKS 관리형 노드 그룹 자동 스케일링) 
# 🚀 Karpenter (동적 노드 프로비저닝)
# 🌐 AWS Load Balancer Controller  
# 📦 External DNS
# 📊 Metrics Server

#==============================================================================
# AWS Node Termination Handler (스팟 인스턴스 안전 종료)
#==============================================================================

# 🎯 Node Termination Handler가 필요한 이유:
# 스팟 중단 대비: 2분 전 중단 예고를 받아 Pod를 안전하게 다른 노드로 이동
# Graceful Shutdown: 진행 중인 작업을 완료하고 새로운 작업 배정 중단
# 서비스 중단 최소화: 무작정 종료되는 것이 아닌 계획된 종료로 영향 최소화
# 데이터 무결성: 데이터베이스 트랜잭션 등 중요한 작업의 안전한 완료 보장

#------------------------------------------------------------------------------
# AWS Node Termination Handler 설치 (DaemonSet 방식)
#------------------------------------------------------------------------------
# 스팟 인스턴스 중단 신호를 감지하여 노드를 안전하게 드레인하는 핸들러
# EC2 Instance Metadata를 폴링하여 SPOT 중단 신호 감지
resource "helm_release" "aws_node_termination_handler" {
  name       = "aws-node-termination-handler"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-node-termination-handler"
  version    = "0.21.0"  # 최신 안정 버전
  namespace  = "kube-system"

  # Instance Metadata 방식 사용 (SQS 대비 간단하고 비용 없음)
  set {
    name  = "enableSpotInterruptionDraining"
    value = "true"
  }

  set {
    name  = "enableRebalanceMonitoring"
    value = "true"
  }

  set {
    name  = "enableScheduledEventDraining"
    value = "true"
  }

  set {
    name  = "enableRebalanceDraining"
    value = "true"
  }

  # 메타데이터 소스 설정
  set {
    name  = "metadataSource"
    value = "imds"  # Instance Metadata Service 사용
  }

  # 드레인 설정
  set {
    name  = "deleteLocalData"
    value = "true"  # 로컬 데이터 삭제 허용
  }

  set {
    name  = "ignoreDaemonSets"
    value = "true"  # DaemonSet은 무시 (시스템 Pod)
  }

  set {
    name  = "podTerminationGracePeriod"
    value = "30"  # Pod 종료 대기 시간 (초)
  }

  set {
    name  = "nodeTerminationGracePeriod"
    value = "110"  # 노드 종료 대기 시간 (초)
  }

  # 리소스 제한 (경량 시스템 컴포넌트)
  set {
    name  = "resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "resources.requests.memory"
    value = "64Mi"
  }

  set {
    name  = "resources.limits.cpu"
    value = "100m"
  }

  set {
    name  = "resources.limits.memory"
    value = "128Mi"
  }

  # 모든 노드에서 실행 (DaemonSet이므로 자동)
  # tolerations는 차트에서 자동으로 모든 taint를 허용하도록 설정됨

  # 보안 설정
  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-node-termination-handler"
  }

  # 로그 레벨 설정
  set {
    name  = "logLevel"
    value = "info"
  }

  # JSON 로그 포맷 (CloudWatch와 호환성)
  set {
    name  = "jsonLogging"
    value = "true"
  }

  # 프로메테우스 메트릭 활성화
  set {
    name  = "enablePrometheusServer"
    value = "true"
  }

  set {
    name  = "prometheusServerPort"
    value = "9092"
  }

  # 웹훅 서버 비활성화 (IMDS 방식 사용)
  set {
    name  = "enableSqsTerminationDraining"
    value = "false"
  }
}

#==============================================================================
# Cluster Autoscaler 설정 (EKS 관리형 노드 그룹 자동 스케일링)
#==============================================================================

#------------------------------------------------------------------------------
# 1. Cluster Autoscaler IAM 역할
#------------------------------------------------------------------------------
# EKS 관리형 노드 그룹을 자동으로 스케줄링하기 위한 IAM 역할
# 시스템 노드(04-eks)는 Cluster Autoscaler가, 앱 노드는 Karpenter가 관리
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
# 2. Cluster Autoscaler 정책
#------------------------------------------------------------------------------
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
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances", 
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeTags",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          # EC2 인스턴스 정보 조회
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:DescribeInstanceTypes"
        ]
        Resource = "*"
      }
    ]
  })
}

#------------------------------------------------------------------------------
# 3. Cluster Autoscaler Helm 설치
#------------------------------------------------------------------------------
# EKS 관리형 노드 그룹을 자동으로 스케일링하는 Cluster Autoscaler
# Pod 스케줄링이 실패하면 노드를 자동으로 추가하고, 미사용 노드는 제거
resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "9.37.0"  # 안정적인 버전
  namespace  = "kube-system"

  # Cluster Autoscaler 설정
  set {
    name  = "autoDiscovery.clusterName"
    value = local.cluster_name
  }

  set {
    name  = "awsRegion"
    value = local.region
  }

  # ServiceAccount 설정
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

  # 노드 선택 (시스템 노드에서 실행)
  set {
    name  = "nodeSelector.node-type"
    value = "system"
  }

  # 톨러레이션 (시스템 노드의 taint 허용)
  set {
    name  = "tolerations[0].key"
    value = "node-type"
  }

  set {
    name  = "tolerations[0].operator"
    value = "Equal"
  }

  set {
    name  = "tolerations[0].value"
    value = "system"
  }

  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }

  # 리소스 제한
  set {
    name  = "resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "resources.requests.memory"
    value = "300Mi"
  }

  set {
    name  = "resources.limits.cpu"
    value = "100m"
  }

  set {
    name  = "resources.limits.memory"
    value = "300Mi"
  }

  # 스케일링 설정
  set {
    name  = "extraArgs.scale-down-delay-after-add"
    value = "10m"  # 노드 추가 후 10분 대기
  }

  set {
    name  = "extraArgs.scale-down-unneeded-time"
    value = "10m"  # 미사용 노드 10분 후 제거
  }

  set {
    name  = "extraArgs.skip-nodes-with-local-storage"
    value = "false"
  }

  set {
    name  = "extraArgs.skip-nodes-with-system-pods"
    value = "false"
  }

  # ✅ 올바른 태그 기반 자동 검색 설정
  set {
    name  = "extraArgs.node-group-auto-discovery"
    value = "asg:tag=k8s.io/cluster-autoscaler/enabled=true,k8s.io/cluster-autoscaler/${local.cluster_name}=owned"
  }

  depends_on = [
    aws_iam_role.cluster_autoscaler_role,
    aws_iam_role_policy.cluster_autoscaler_policy
  ]
}

#==============================================================================
# Karpenter - 동적 노드 프로비저닝 및 오토스케일링
#==============================================================================

# 🎯 Karpenter가 필요한 이유:
# 비용 절약: 스팟 인스턴스 활용으로 최대 90% 비용 절감
# 자동 스케일링: Pod 요구사항에 맞춰 적절한 인스턴스 타입 자동 선택
# 리소스 효율: 사용하지 않는 노드는 자동으로 제거하여 비용 최적화
# 다양한 워크로드: CPU/메모리/GPU 등 다양한 요구사항에 맞는 노드 제공

#------------------------------------------------------------------------------
# 4. Karpenter용 서브넷 및 보안 그룹 태그 추가
#------------------------------------------------------------------------------

# 프라이빗 서브넷에 Karpenter 디스커버리 태그 추가
resource "aws_ec2_tag" "private_subnet_karpenter_discovery" {
  count       = length(local.private_subnet_ids)
  resource_id = local.private_subnet_ids[count.index]
  key         = "karpenter.sh/discovery"
  value       = local.cluster_name
}

# EKS 노드 보안 그룹에 Karpenter 디스커버리 태그 추가  
resource "aws_ec2_tag" "eks_node_sg_karpenter_discovery" {
  resource_id = local.eks_node_sg_id
  key         = "karpenter.sh/discovery"
  value       = local.cluster_name
}


#------------------------------------------------------------------------------
# 1. Karpenter Controller를 위한 IAM 역할 (IRSA 방식)
#------------------------------------------------------------------------------
resource "aws_iam_role" "karpenter_controller_role" {
  name = "${local.project_name}-${local.environment}-karpenter-controller-role"

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
            "${replace(local.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:karpenter:karpenter"
            "${replace(local.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-karpenter-controller-role"
    Component = "Karpenter-Controller"
  })
}

#------------------------------------------------------------------------------
# 2. Karpenter Controller 정책
#------------------------------------------------------------------------------
resource "aws_iam_role_policy" "karpenter_controller_policy" {
  name = "${local.project_name}-${local.environment}-karpenter-controller-policy"
  role = aws_iam_role.karpenter_controller_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # EC2 인스턴스 관리
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateTags",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeImages", 
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets",
          "ec2:RequestSpotInstances",
          "ec2:RunInstances",
          "ec2:TerminateInstances", 
          
          # 🔧 누락된 권한들 추가!
          "ec2:DeleteLaunchTemplate",
          "ec2:ModifyLaunchTemplate",
          "ec2:CreateLaunchTemplateVersion",
          "ec2:DeleteLaunchTemplateVersions",
          "ec2:DescribeLaunchTemplateVersions",
          
          # SQS (Spot 인터럽션 처리)
          "sqs:DeleteMessage",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes", 
          "sqs:ReceiveMessage",
          # EKS 클러스터 정보
          "eks:DescribeCluster",

          # Pricing 정보 조회
          "pricing:GetProducts"

          
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.project_name}-${local.environment}-karpenter-node-role"
      }
    ]
  })
}

#------------------------------------------------------------------------------
# 3. Karpenter 노드를 위한 IAM 역할
#------------------------------------------------------------------------------
resource "aws_iam_role" "karpenter_node_role" {
  name = "${local.project_name}-${local.environment}-karpenter-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-karpenter-node-role"
    Component = "Karpenter-Nodes"
  })
}

#------------------------------------------------------------------------------
# 4. Karpenter 노드 정책들 연결 (통합 버전)
#------------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "karpenter_node_eks_worker_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.karpenter_node_role.name
}

resource "aws_iam_role_policy_attachment" "karpenter_node_eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.karpenter_node_role.name
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ecr_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.karpenter_node_role.name
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ssm_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.karpenter_node_role.name
}

#------------------------------------------------------------------------------
# 5. Karpenter 노드 인스턴스 프로파일
#------------------------------------------------------------------------------
resource "aws_iam_instance_profile" "karpenter_node_profile" {
  name = "${local.project_name}-${local.environment}-karpenter-node-profile"
  role = aws_iam_role.karpenter_node_role.name

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-karpenter-node-profile"
    Component = "Karpenter-Nodes"
  })
}

#------------------------------------------------------------------------------
# 6. Karpenter Namespace 생성 (기존 이름 유지)
#------------------------------------------------------------------------------
resource "kubernetes_namespace" "karpenter" {
  metadata {
    name = "karpenter"
    
    labels = {
      "name" = "karpenter"
      "app.kubernetes.io/name" = "karpenter"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

#------------------------------------------------------------------------------
# 7. Karpenter CRD를 개별 리소스로 분리 (for_each 제거)
#------------------------------------------------------------------------------

# 개별 CRD 다운로드
data "http" "karpenter_nodeclaims_crd" {
  url = "https://raw.githubusercontent.com/aws/karpenter/v1.5.0/pkg/apis/crds/karpenter.sh_nodeclaims.yaml"
}

data "http" "karpenter_nodepools_crd" {
  url = "https://raw.githubusercontent.com/aws/karpenter/v1.5.0/pkg/apis/crds/karpenter.sh_nodepools.yaml"
}

data "http" "karpenter_ec2nodeclasses_crd" {
  url = "https://raw.githubusercontent.com/aws/karpenter-provider-aws/v1.5.0/pkg/apis/crds/karpenter.k8s.aws_ec2nodeclasses.yaml"
}

# 개별 CRD 설치
resource "kubectl_manifest" "karpenter_nodeclaims_crd" {
  yaml_body = data.http.karpenter_nodeclaims_crd.response_body
  depends_on = [kubernetes_namespace.karpenter]
}

resource "kubectl_manifest" "karpenter_nodepools_crd" {
  yaml_body = data.http.karpenter_nodepools_crd.response_body
  depends_on = [kubernetes_namespace.karpenter]
}

resource "kubectl_manifest" "karpenter_ec2nodeclasses_crd" {
  yaml_body = data.http.karpenter_ec2nodeclasses_crd.response_body
  depends_on = [kubernetes_namespace.karpenter]
}

#------------------------------------------------------------------------------
# 8. Karpenter Controller 설치 (개별 CRD 의존성)
#------------------------------------------------------------------------------
resource "helm_release" "karpenter" {
  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "1.5.0"  # 🎯 최신 안정 버전
  namespace  = kubernetes_namespace.karpenter.metadata[0].name

  create_namespace = false  # namespace는 이미 생성됨
  
  # 🔧 CRD 설치 건드리지 않도록 설정
  skip_crds = true  # Helm이 CRD를 건드리지 않음
  
  # 서비스 어카운트 IAM 역할 연결
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.karpenter_controller_role.arn
  }

  # 클러스터 설정
  set {
    name  = "settings.clusterName"
    value = local.cluster_name
  }

  # 인스턴스 프로파일 설정
  set {
    name  = "settings.defaultInstanceProfile"
    value = aws_iam_instance_profile.karpenter_node_profile.name
  }

  # Feature Gates 활성화
  set {
    name  = "settings.featureGates.drift"
    value = "true"
  }

  # 리소스 제한 설정
  set {
    name  = "controller.resources.requests.cpu"
    value = "250m"
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "512Mi"
  }

  set {
    name  = "controller.resources.limits.cpu"
    value = "1000m"
  }

  set {
    name  = "controller.resources.limits.memory"
    value = "1Gi"
  }

  # 고가용성 설정
  set {
    name  = "replicas"
    value = "1"
  }

  # Toleration 설정
  set {
    name  = "tolerations[0].key"
    value = "node-type"
  }

  set {
    name  = "tolerations[0].value"
    value = "system"
  }

  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }

  # 업데이트 전략
  set {
    name  = "updateStrategy.type"
    value = "RollingUpdate"
  }

  # Pod Disruption Budget 설정
  set {
    name  = "podDisruptionBudget.enabled"
    value = "false"  # 단일 replica이므로 비활성화
  }

  # 어피니티 및 톨러레이션 설정
  set {
    name  = "affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].key"
    value = "kubernetes.io/os"
  }

  set {
    name  = "affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].operator"
    value = "In"
  }

  set {
    name  = "affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].values[0]"
    value = "linux"
  }

  # ✅ 개별 CRD 의존성으로 변경
  depends_on = [
    kubectl_manifest.karpenter_nodeclaims_crd,
    kubectl_manifest.karpenter_nodepools_crd,
    kubectl_manifest.karpenter_ec2nodeclasses_crd
  ]
}

#------------------------------------------------------------------------------
# 9. EC2NodeClass 정의 (AL2023 + nodeadm 최신 방식)
#------------------------------------------------------------------------------

# EKS 클러스터 정보 조회 (Karpenter userData용)
data "aws_eks_cluster" "cluster" {
  name = local.cluster_name
}

resource "kubectl_manifest" "karpenter_ec2nodeclass" {
  yaml_body = <<-EOT
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: ${local.project_name}-${local.environment}-default
spec:
  # 🔧 AMI 패밀리를 AL2023으로 설정 (최신 권장)
  amiFamily: AL2023
  
  # 🔧 태그 기반 AMI 선택 (alias 대신 tags 사용)
  amiSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${local.cluster_name}"
    - name: "amazon-eks-node-al2023-*"  # AL2023 AMI 패턴
  
  # 서브넷 선택 - 태그 기반 자동 검색
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${local.cluster_name}"
  
  # 보안 그룹 선택 - 태그 기반 자동 검색
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${local.cluster_name}"
  
  # IAM 인스턴스 프로파일
  instanceProfile: ${aws_iam_instance_profile.karpenter_node_profile.name}
  
  # 🔧 올바른 userData - base64encode로 인코딩 (핵심!)
  userData: ${base64encode(<<-EOF
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: ${local.cluster_name}
    endpoint: ${data.aws_eks_cluster.cluster.endpoint}
    certificateAuthority:
      data: ${data.aws_eks_cluster.cluster.certificate_authority[0].data}
  kubelet:
    flags:
      - --register-with-taints=karpenter.sh/unregistered:NoExecute
EOF
  )}
  
  # 블록 디바이스 매핑 - AL2023 기본값
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeSize: 20Gi
        volumeType: gp3
        deleteOnTermination: true
        encrypted: true
  
  # 메타데이터 옵션 - 보안 강화 설정
  metadataOptions:
    httpEndpoint: enabled
    httpProtocolIPv6: disabled
    httpPutResponseHopLimit: 2
    httpTokens: required
  
  # 상세 모니터링 비활성화 (비용 절약)
  detailedMonitoring: false
  
  # 태그 - 리소스 식별 및 관리용
  tags:
    Name: "${local.project_name}-${local.environment}-karpenter-node"
    karpenter.sh/discovery: "${local.cluster_name}"
    Purpose: "Karpenter Managed Node"
    Component: "Karpenter-Nodes"
    Environment: "${local.environment}"
    Project: "${local.project_name}"
    AMIFamily: "AL2023"
EOT

  # kubectl 설정
  force_conflicts   = true
  server_side_apply = true
  
  # ✅ 올바른 의존성
  depends_on = [
    kubectl_manifest.karpenter_nodeclaims_crd,
    kubectl_manifest.karpenter_nodepools_crd,
    kubectl_manifest.karpenter_ec2nodeclasses_crd,
    helm_release.karpenter,
    data.aws_eks_cluster.cluster  # 클러스터 정보 조회 후
  ]
}

#------------------------------------------------------------------------------
# 10. NodePool 정의 (v1.5.0 호환 버전)
#------------------------------------------------------------------------------
resource "kubectl_manifest" "karpenter_nodepool" {
  yaml_body = <<-EOT
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: ${local.project_name}-${local.environment}-spot-small
spec:
  # 노드 템플릿
  template:
    metadata:
      labels:
        node-type: application
        capacity-type: spot
        instance-size: small
        cost-optimized: "true"
      annotations:
        karpenter.sh/do-not-evict: "false"
        spot-instance: "true"
    spec:
      # ✅ NodeClass 참조
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: ${local.project_name}-${local.environment}-default
      
      # 인스턴스 요구사항 (스팟 + t3.small/t3a.small만)
      requirements:
        - key: "kubernetes.io/arch"
          operator: In
          values: ["amd64"]
        - key: "karpenter.sh/capacity-type"
          operator: In
          values: ["spot"]  # 스팟 인스턴스만!
        - key: "node.kubernetes.io/instance-type"
          operator: In
          values: ["t3.medium", "t3a.medium"]  # 비용 최적화
      
      # ✅ 노드 수명 관리 (올바른 위치)
      expireAfter: 1h  # 1시간 미사용시 제거
      terminationGracePeriod: 5m
      
      # 스팟 인스턴스 Taints (필요시 주석 해제)
      # taints:
      #   - key: spot-instance
      #     value: "true"
      #     effect: NoSchedule
  
  # 리소스 제한 (30개 t3.small 기준: 60 vCPU, 60GB RAM)
  limits:
    cpu: "60"
    memory: "60Gi"
  
  # ✅ 노드 교체 정책 (v1.5.0 호환)
  disruption:
    consolidationPolicy: WhenEmpty  # 빈 노드만 제거
    consolidateAfter: 10s  # 빠른 통합
    # expireAfter는 여기서 제거! (template.spec으로 이동됨)
    budgets:
      - nodes: "10%"  # 동시에 교체할 노드 비율
EOT

  # kubectl 설정
  force_conflicts   = true
  server_side_apply = true
  
  # 🔧 의존성 간소화
  depends_on = [
    kubectl_manifest.karpenter_ec2nodeclass,
    helm_release.karpenter  # 컨트롤러 추가
  ]
}

#==============================================================================
# AWS Load Balancer Controller 설정
#==============================================================================

#------------------------------------------------------------------------------
# 11. AWS Load Balancer Controller IAM 역할
#------------------------------------------------------------------------------
# ALB/NLB를 자동으로 생성하고 관리하는 Controller용 IAM 역할
# Ingress 리소스에 따라 AWS 로드밸런서를 프로비저닝
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
# 12. AWS Load Balancer Controller 공식 IAM 정책 (교체)
#------------------------------------------------------------------------------
# AWS 공식 정책으로 교체 - SecurityGroup 생성 권한 포함
resource "aws_iam_policy" "aws_load_balancer_controller_policy" {
  name        = "${local.project_name}-${local.environment}-AWSLoadBalancerControllerIAMPolicy"
  description = "IAM policy for AWS Load Balancer Controller (Official)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:CreateServiceLinkedRole"
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
          "cognito-idp:DescribeUserPoolClient",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "iam:ListServerCertificates",
          "iam:GetServerCertificate",
          "waf-regional:GetWebACL",
          "waf-regional:GetWebACLForResource", 
          "waf-regional:AssociateWebACL",
          "waf-regional:DisassociateWebACL",
          "wafv2:GetWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL",
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
          # 🔧 핵심: SecurityGroup 생성 권한!
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:CreateSecurityGroup"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags"
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
          # 🔥 리스너 관련 모든 권한
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:ModifyListener",           # 🆕 추가
          "elasticloadbalancing:DescribeListeners",        # 🆕 추가
          "elasticloadbalancing:DescribeListenerCertificates", # 🆕 추가
          
          # 🔥 리스너 규칙 관련 모든 권한  
          "elasticloadbalancing:CreateRule",
          "elasticloadbalancing:DeleteRule",
          "elasticloadbalancing:ModifyRule",
          "elasticloadbalancing:DescribeRules",            # 🆕 추가
          
          # 🔥 로드밸런서 관련 추가 권한
          "elasticloadbalancing:CreateLoadBalancer",       # 🆕 추가
          "elasticloadbalancing:DeleteLoadBalancer",       # 🆕 추가
          "elasticloadbalancing:ModifyLoadBalancerAttributes", # 🆕 추가
          "elasticloadbalancing:DescribeLoadBalancers",    # 🆕 추가
          "elasticloadbalancing:DescribeLoadBalancerAttributes", # 🆕 추가
          
          # 🔥 타겟 그룹 관련 추가 권한
          "elasticloadbalancing:CreateTargetGroup",        # 🆕 추가
          "elasticloadbalancing:DeleteTargetGroup",        # 🆕 추가
          "elasticloadbalancing:ModifyTargetGroup",        # 🆕 추가
          "elasticloadbalancing:ModifyTargetGroupAttributes", # 🆕 추가
          "elasticloadbalancing:DescribeTargetGroups",     # 🆕 추가
          "elasticloadbalancing:DescribeTargetGroupAttributes", # 🆕 추가
          "elasticloadbalancing:DescribeTargetHealth",     # 🆕 추가
          "elasticloadbalancing:RegisterTargets",          # 🆕 추가
          "elasticloadbalancing:DeregisterTargets",        # 🆕 추가
          
          # 🔥 SSL/TLS 관련 권한
          "elasticloadbalancing:DescribeSSLPolicies",      # 🆕 추가
          
          # 🔥 태그 관련 권한
          "elasticloadbalancing:AddTags",                  # 🆕 추가
          "elasticloadbalancing:RemoveTags",               # 🆕 추가
          "elasticloadbalancing:DescribeTags",             # 🆕 추가
          
          # 🔥 기타 필수 권한
          "elasticloadbalancing:SetIpAddressType",         # 🆕 추가
          "elasticloadbalancing:SetSecurityGroups",        # 🆕 추가
          "elasticloadbalancing:SetSubnets"                # 🆕 추가
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
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets"
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

# 새로운 정책을 역할에 연결
resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller_policy_new" {
  policy_arn = aws_iam_policy.aws_load_balancer_controller_policy.arn
  role       = aws_iam_role.aws_load_balancer_controller_role.name
}

#------------------------------------------------------------------------------
# 13. AWS Load Balancer Controller Helm 설치
#------------------------------------------------------------------------------
# Kubernetes Ingress 리소스를 AWS ALB/NLB로 자동 변환하는 Controller
# 도메인 기반 라우팅을 위한 핵심 컴포넌트
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.8.1"  # 최신 안정 버전
  namespace  = "kube-system"

  # 클러스터 이름 설정
  set {
    name  = "clusterName"
    value = local.cluster_name
  }

  # ServiceAccount 자동 생성 및 IAM 역할 연결
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

  # 리소스 제한 (작은 클러스터용 최적화)
  set {
    name  = "resources.limits.cpu"
    value = "200m"
  }

  set {
    name  = "resources.limits.memory"
    value = "500Mi"
  }

  set {
    name  = "resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "resources.requests.memory"
    value = "200Mi"
  }

  # 노드 셀렉터 (시스템 노드에만 배포)
  set {
    name  = "nodeSelector.node-type"
    value = "system"
  }

  # 🔧 톨러레이션 추가 (시스템 노드의 taint 허용)
  set {
    name  = "tolerations[0].key"
    value = "node-type"
  }

  set {
    name  = "tolerations[0].operator"
    value = "Equal"
  }

  set {
    name  = "tolerations[0].value"
    value = "system"
  }

  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }

  # 고가용성을 위한 replica 설정
  set {
    name  = "replicaCount"
    value = "1"  # 개발 환경이므로 1개
  }

  depends_on = [
    aws_iam_role.aws_load_balancer_controller_role,
    kubectl_manifest.karpenter_nodepool  # Karpenter 설치 후에 설치
  ]
}

#==============================================================================
# External DNS 설정
#==============================================================================

#------------------------------------------------------------------------------
# 14. External DNS IAM 역할
#------------------------------------------------------------------------------
# Route53 DNS 레코드를 자동으로 생성/관리하는 Controller용 IAM 역할
# Ingress 생성 시 자동으로 DNS A 레코드가 생성되어 도메인 관리 자동화
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

# External DNS Route53 정책
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
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets",
          "route53:GetChange"
        ]
        Resource = "arn:aws:route53:::hostedzone/*"  # 모든 호스팅 존에 대한 권한
      },
      {
        Effect = "Allow"
        Action = [
          # Route53 호스팅 존 조회 권한
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets"
        ]
        Resource = "*"
      }
    ]
  })
}

#------------------------------------------------------------------------------
# 15. External DNS Helm 설치
#------------------------------------------------------------------------------
# Kubernetes Ingress와 Service를 감시하여 Route53 DNS 레코드 자동 생성
# domain_name이 설정된 Ingress가 생성되면 자동으로 A 레코드 추가
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

  # AWS 리전 설정
  set {
    name  = "aws.region"
    value = local.region
  }

  # 도메인 필터 설정 - 서브도메인도 포함하도록 수정
  set {
    name  = "domainFilters[0]"
    value = "tebutebu.com"  # ✅ 상위 도메인으로 설정하여 모든 서브도메인 포함
  }

  # 정책 설정 (sync = 자동 생성/삭제, upsert-only = 생성만)
  set {
    name  = "policy"
    value = "upsert-only"  # 안전하게 생성만 (삭제 방지)
  }

  # 소스 설정 (Ingress와 Service 모니터링)
  set {
    name  = "sources[0]"
    value = "ingress"
  }

  set {
    name  = "sources[1]"
    value = "service"
  }

  # ServiceAccount 설정
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

  # 리소스 제한 (가벼운 워크로드)
  set {
    name  = "resources.limits.cpu"
    value = "100m"
  }

  set {
    name  = "resources.limits.memory"
    value = "128Mi"
  }

  set {
    name  = "resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "resources.requests.memory"
    value = "64Mi"
  }

  # 노드 셀렉터 (시스템 노드에만 배포)
  set {
    name  = "nodeSelector.node-type"
    value = "system"
  }

  # 🔧 톨러레이션 추가 (시스템 노드의 taint 허용)
  set {
    name  = "tolerations[0].key"
    value = "node-type"
  }

  set {
    name  = "tolerations[0].operator"
    value = "Equal"
  }

  set {
    name  = "tolerations[0].value"
    value = "system"
  }

  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }

  # 로그 레벨 설정 (개발 환경에서 디버깅 정보 확인)
  set {
    name  = "logLevel"
    value = "info"
  }

  # DNS 레코드 TTL 설정
  set {
    name  = "txtOwnerId"
    value = "${local.project_name}-${local.environment}"
  }

  # 건조 실행 모드 비활성화 (실제 DNS 레코드 생성)
  set {
    name  = "dryRun"
    value = "false"
  }

  depends_on = [
    aws_iam_role.external_dns_role,
    helm_release.aws_load_balancer_controller
  ]
}

#==============================================================================
# Metrics Server 설정 (리소스 모니터링)
#==============================================================================

#------------------------------------------------------------------------------
# 16. Metrics Server Helm 설치
#------------------------------------------------------------------------------
# Kubernetes 리소스 사용량 메트릭 수집 서버
# kubectl top, HPA (Horizontal Pod Autoscaler), VPA 동작을 위한 필수 컴포넌트
# CPU/Memory 사용량을 metrics.k8s.io API로 제공
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.12.0"
  namespace  = "kube-system"

  # ✅ 리소스 제한만 설정
  set {
    name  = "resources.limits.cpu"
    value = "100m"
  }

  set {
    name  = "resources.limits.memory"
    value = "128Mi"
  }

  set {
    name  = "resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "resources.requests.memory"
    value = "64Mi"
  }

  # 고가용성 설정 (단일 인스턴스)
  set {
    name  = "replicas"
    value = "1"  # 개발 환경이므로 1개
  }

  # 노드 셀렉터 (시스템 노드에만 배포)
  set {
    name  = "nodeSelector.node-type"
    value = "system"
  }

  # 🔧 톨러레이션 추가 (시스템 노드의 taint 허용)
  set {
    name  = "tolerations[0].key"
    value = "node-type"
  }

  set {
    name  = "tolerations[0].operator"
    value = "Equal"
  }

  set {
    name  = "tolerations[0].value"
    value = "system"
  }

  set {
    name  = "tolerations[0].effect"
    value = "NoSchedule"
  }

  # Pod 우선순위 설정 (시스템 중요 컴포넌트)
  set {
    name  = "priorityClassName"
    value = "system-cluster-critical"
  }

  # 보안 컨텍스트 설정
  set {
    name  = "securityContext.allowPrivilegeEscalation"
    value = "false"
  }

  set {
    name  = "securityContext.readOnlyRootFilesystem"
    value = "true"
  }

  set {
    name  = "securityContext.runAsNonRoot"
    value = "true"
  }

  set {
    name  = "securityContext.runAsUser"
    value = "1000"
  }

  # 서비스 설정
  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  set {
    name  = "service.port"
    value = "443"
  }

  # 라이브니스 및 레디니스 프로브 설정
  set {
    name  = "livenessProbe.httpGet.path"
    value = "/livez"
  }

  set {
    name  = "livenessProbe.httpGet.port"
    value = "https"
  }

  set {
    name  = "livenessProbe.httpGet.scheme"
    value = "HTTPS"
  }

  set {
    name  = "readinessProbe.httpGet.path"
    value = "/readyz"
  }

  set {
    name  = "readinessProbe.httpGet.port"
    value = "https"
  }

  set {
    name  = "readinessProbe.httpGet.scheme"
    value = "HTTPS"
  }

  # 업데이트 전략
  set {
    name  = "updateStrategy.type"
    value = "RollingUpdate"
  }

  # Pod Disruption Budget 설정
  set {
    name  = "podDisruptionBudget.enabled"
    value = "false"  # 단일 replica이므로 비활성화
  }

  # 어피니티 및 톨러레이션 설정
  set {
    name  = "affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].key"
    value = "kubernetes.io/os"
  }

  set {
    name  = "affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].operator"
    value = "In"
  }

  set {
    name  = "affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].values[0]"
    value = "linux"
  }

  depends_on = [
    helm_release.external_dns
  ]
}

#==============================================================================
# 🚀 Karpenter 노드를 위한 aws-auth ConfigMap 설정
#==============================================================================

#------------------------------------------------------------------------------
# 17. aws-auth ConfigMap에 Karpenter 노드 역할 추가  
#------------------------------------------------------------------------------
# Karpenter가 생성한 노드들이 클러스터에 조인할 수 있도록 IAM 역할 등록
# 기존 aws-auth ConfigMap에 Karpenter 노드 역할을 추가하여 패치
resource "kubernetes_config_map_v1_data" "aws_auth_karpenter" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode([
      # 기존 EKS 관리형 노드 그룹 역할 (04-eks에서 생성된 것 유지)
      {
        rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.project_name}-${local.environment}-eks-node-group-role"
        username = "system:node:{{EC2PrivateDNSName}}"
        groups = [
          "system:bootstrappers",
          "system:nodes"
        ]
      },
      # ✅ Karpenter 노드 역할 추가
      {
        rolearn  = aws_iam_role.karpenter_node_role.arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups = [
          "system:bootstrappers",
          "system:nodes"
        ]
      }
    ])
  }

  # Karpenter IAM 역할이 생성된 후에 실행
  depends_on = [
    aws_iam_role.karpenter_node_role,
    aws_iam_instance_profile.karpenter_node_profile
  ]

  # ConfigMap 업데이트 시 강제 적용
  force = true
}

