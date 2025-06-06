#==============================================================================
# EKS 클러스터 및 노드 그룹 보안 그룹
#==============================================================================

# 🎯 EKS 클러스터 보안 그룹:
# API 서버 보호: Kubernetes API 서버에 대한 접근 제어
# 워커 노드와의 통신: 클러스터가 노드들을 관리할 수 있도록 HTTPS 허용
# 🖥️ EKS 노드 보안 그룹:
# 노드 간 통신: Pod들이 서로 통신할 수 있도록 (CNI 네트워킹)
# ALB 연결: 로드 밸런서가 Pod로 트래픽을 전달할 수 있도록
# 클러스터 관리: EKS 컨트롤 플레인이 노드를 관리할 수 있도록
# 🗄️ MySQL 연결 규칙:
# 데이터베이스 접근: EKS Pod들이 03-db의 MySQL EC2에 연결할 수 있도록
# 보안 유지: 기존 MySQL 보안 그룹을 수정하지 않고 규칙만 추가

#------------------------------------------------------------------------------
# 1. EKS 클러스터 보안 그룹
#------------------------------------------------------------------------------
# EKS 컨트롤 플레인(마스터 노드들)을 위한 보안 그룹
# AWS가 관리하는 Kubernetes API 서버들이 사용
resource "aws_security_group" "eks_cluster_sg" {
  name        = "${local.project_name}-${local.environment}-eks-cluster-sg"
  description = "Security group for EKS cluster control plane"
  vpc_id      = local.vpc_id

  # 인바운드 규칙: 워커 노드에서 클러스터로의 HTTPS 통신 허용
  ingress {
    description = "HTTPS from worker nodes to cluster API"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = local.private_subnet_cidrs  # 동적으로 가져오기
  }

  # 아웃바운드 규칙: 모든 트래픽 허용
  # 클러스터가 워커 노드, AWS API, 인터넷 등과 통신할 수 있도록
  egress {
    description = "All outbound traffic from cluster"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name      = "${local.project_name}-${local.environment}-eks-cluster-sg"
      Purpose   = "EKS Cluster Control Plane Security"
      Component = "EKS-Control-Plane"
    }
  )
}

#------------------------------------------------------------------------------
# 2. EKS 워커 노드 보안 그룹
#------------------------------------------------------------------------------
# EKS 워커 노드(EC2 인스턴스들)를 위한 보안 그룹
# 애플리케이션 Pod들이 실행되는 노드들이 사용
resource "aws_security_group" "eks_node_sg" {
  name        = "${local.project_name}-${local.environment}-eks-node-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = local.vpc_id

  # 1) 노드간 모든 트래픽 허용
  ingress {
    description = "All traffic between worker nodes"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # 2) VPC 내에서 필요한 포트들만 허용
  ingress {
    description = "Required ports from VPC"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr_block]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name      = "${local.project_name}-${local.environment}-eks-node-sg"
      Purpose   = "EKS Worker Nodes Security"
      Component = "EKS-Worker-Nodes"
    }
  )
}

#------------------------------------------------------------------------------
# 3. MySQL 보안 그룹에 EKS 노드 접근 규칙 추가
#------------------------------------------------------------------------------
# 03-db에서 생성한 MySQL 보안 그룹에 EKS 노드들의 접근을 허용하는 규칙 추가
# 애플리케이션 Pod들이 MySQL 데이터베이스에 연결할 수 있도록 함
resource "aws_security_group_rule" "mysql_from_eks_nodes" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_node_sg.id
  security_group_id        = local.mysql_security_group_id
  description              = "MySQL access from EKS worker nodes"
}

#==============================================================================
# EKS 클러스터용 IAM 역할 및 정책
#==============================================================================
# 🎯 EKS 클러스터 역할이 필요한 이유:
# 클러스터 관리: EKS가 Kubernetes 컨트롤 플레인을 운영하기 위해
# AWS 리소스 접근: 로드밸런서, 보안그룹, VPC 등을 자동으로 관리
# 로깅 및 모니터링: CloudWatch에 클러스터 로그 전송
# 🖥️ 노드 그룹 역할이 필요한 이유:
# 클러스터 조인: 워커 노드가 EKS 클러스터에 참여
# 이미지 다운로드: ECR에서 컨테이너 이미지 가져오기
# 네트워킹: Pod IP 할당 및 VPC 네트워킹 관리
# 🔒 최소 권한 원칙:
# AWS 관리형 정책만 사용하여 과도한 권한 방지
# 각 역할은 꼭 필요한 작업만 수행할 수 있도록 제한

#------------------------------------------------------------------------------
# 5. EKS 클러스터 서비스 역할
#------------------------------------------------------------------------------
# EKS 클러스터가 AWS 서비스들을 관리하기 위해 필요한 IAM 역할
# 이 역할로 EKS가 EC2, VPC, Route53 등의 AWS 리소스에 접근할 수 있음
resource "aws_iam_role" "eks_cluster_role" {
  name = "${local.project_name}-${local.environment}-eks-cluster-role"

  # EKS 서비스가 이 역할을 assume(사용)할 수 있도록 신뢰 정책 설정
  # 즉, EKS 서비스만이 이 역할의 권한을 사용할 수 있음
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"  # EKS 서비스만 이 역할 사용 가능
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.project_name}-${local.environment}-eks-cluster-role"
      Purpose     = "EKS Cluster Service Role"
      Component   = "EKS-Control-Plane"
    }
  )
}

#------------------------------------------------------------------------------
# 6. EKS 클러스터 정책 연결
#------------------------------------------------------------------------------
# AWS에서 제공하는 관리형 정책을 클러스터 역할에 연결
# 이 정책으로 EKS가 클러스터를 관리하는데 필요한 모든 권한을 얻음
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# AmazonEKSClusterPolicy에 포함된 주요 권한들:
# - EC2 인스턴스 관리 (노드 그룹용)
# - VPC 네트워킹 설정
# - IAM 역할 관리
# - CloudWatch 로깅
# - Route53 DNS 관리 등

#==============================================================================
# EKS 클러스터 생성
#==============================================================================
# 🎯 클러스터 버전 1.28:
# 안정성: 현재 AWS에서 지원하는 안정적인 최신 버전
# 보안 패치: 최신 보안 업데이트 포함
# 기능성: 최신 Kubernetes 기능 사용 가능
# 🌐 엔드포인트 설정 (Public + Private):
# Public Access: 개발자가 로컬에서 kubectl 사용 가능
# Private Access: 워커 노드들이 클러스터와 안전하게 통신
# 유연성: 필요에 따라 접근 방식 선택 가능
# 📊 클러스터 로깅:
# 디버깅: 문제 발생 시 로그 분석으로 원인 파악
# 보안 감사: 누가 언제 무엇을 했는지 추적
# 성능 분석: API 응답 시간, 스케줄링 성능 등 모니터링
# 🔒 암호화 설정:
# 데이터 보호: Kubernetes Secret이 평문으로 저장되지 않음
# 규정 준수: 보안 요구사항 충족
# AWS 통합: KMS와 완전 통합으로 키 관리 자동화

#------------------------------------------------------------------------------
# 7. EKS 클러스터 생성
#------------------------------------------------------------------------------
# Amazon EKS 클러스터는 Kubernetes 컨트롤 플레인을 관리하는 서비스
# 여기서 생성되는 것은 마스터 노드들(API 서버, etcd, 스케줄러 등)
# 워커 노드는 별도로 생성해야 함
resource "aws_eks_cluster" "main" {
  # 클러스터 기본 설정
  name     = "${local.project_name}-${local.environment}-eks-cluster"
  version  = "1.28"  # Kubernetes 버전 (안정적인 최신 버전 사용)
  role_arn = aws_iam_role.eks_cluster_role.arn

  # VPC 구성: 클러스터가 사용할 서브넷 지정
  vpc_config {
    subnet_ids = concat(
      local.public_subnet_ids,
      local.private_subnet_ids
    )

    security_group_ids = [aws_security_group.eks_cluster_sg.id]

    # API 서버 엔드포인트 접근 설정 (직접 속성으로)
    endpoint_private_access = true    # 프라이빗 접근 허용
    endpoint_public_access  = true    # 퍼블릭 접근 허용
    public_access_cidrs     = ["0.0.0.0/0"]  # 퍼블릭 접근 허용 CIDR
  }

  # 클러스터 로깅 설정: CloudWatch Logs로 전송
  # Kubernetes 컨트롤 플레인의 각종 로그를 수집하여 모니터링 및 디버깅에 활용
  enabled_cluster_log_types = [
    "api",           # Kubernetes API 서버 로그 (API 호출, 인증 등)
    "audit",         # 클러스터 감사 로그 (누가 무엇을 했는지 추적)
    "authenticator", # AWS IAM Authenticator 로그 (IAM 인증 관련)
    "controllerManager", # Controller Manager 로그 (리소스 상태 관리)
    "scheduler"      # 스케줄러 로그 (Pod 배치 결정)
  ]

  # 의존성 설정: IAM 정책이 연결된 후에 클러스터 생성
  # 이렇게 하지 않으면 권한 부족으로 클러스터 생성 실패 가능
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.project_name}-${local.environment}-eks-cluster"
      Purpose     = "Kubernetes Control Plane"
      Component   = "EKS-Cluster"
      Environment = local.environment
    }
  )

  #------------------------------------------------------------------------------
  # 8. EKS Access Entry (jacky IAM 사용자 권한 추가)  
  #------------------------------------------------------------------------------
  # jacky IAM 사용자가 EKS 클러스터와 대시보드에 접근할 수 있도록 권한 부여
  # 이렇게 하지 않으면 AWS 콘솔에서 "접근 권한이 없습니다" 메시지 표시
}

#------------------------------------------------------------------------------
# 10. EKS 클러스터 정보 확인용 데이터 소스
#------------------------------------------------------------------------------
# EKS 클러스터가 생성된 후 클러스터 정보를 가져오는 데이터 소스
# kubectl 설정, 인증서 정보 등을 다른 리소스에서 사용할 때 필요
data "aws_eks_cluster" "main" {
  name       = aws_eks_cluster.main.name
  depends_on = [aws_eks_cluster.main]
}

# EKS 클러스터 인증 정보 데이터 소스
# Kubernetes provider가 클러스터에 접근할 때 사용할 토큰 생성
data "aws_eks_cluster_auth" "main" {
  name       = aws_eks_cluster.main.name
  depends_on = [aws_eks_cluster.main]
}

#==============================================================================
# EKS 노드 그룹용 IAM 역할 및 정책
#==============================================================================
# 🖥️ 노드 그룹 역할이 필요한 이유:
# 클러스터 조인: 워커 노드가 EKS 클러스터에 참여
# 이미지 다운로드: ECR에서 컨테이너 이미지 가져오기
# 네트워킹: Pod IP 할당 및 VPC 네트워킹 관리

#------------------------------------------------------------------------------
# 11. EKS 노드 그룹 역할
#------------------------------------------------------------------------------
# 워커 노드(EC2 인스턴스)들이 사용할 IAM 역할
# 이 역할로 노드들이 ECR에서 이미지를 가져오고, CloudWatch에 로그를 보내는 등의 작업 수행
resource "aws_iam_role" "eks_node_group_role" {
  name = "${local.project_name}-${local.environment}-eks-node-group-role"

  # EC2 서비스가 이 역할을 assume할 수 있도록 설정
  # 워커 노드는 실제로는 EC2 인스턴스이기 때문
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"  # EC2 인스턴스가 이 역할 사용
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.project_name}-${local.environment}-eks-node-group-role"
      Purpose     = "EKS Node Group Role"
      Component   = "EKS-Worker-Nodes"
    }
  )
}

#------------------------------------------------------------------------------
# 12. EKS 워커 노드 정책들 연결
#------------------------------------------------------------------------------

# 12-1. EKS 워커 노드 기본 정책
# 노드가 EKS 클러스터에 조인하고 기본적인 Kubernetes 작업을 수행하는데 필요
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group_role.name
}

# 12-2. CNI(Container Network Interface) 정책  
# Pod들 간의 네트워킹을 위해 VPC의 IP 주소를 관리하는 권한
# AWS VPC CNI가 ENI(Elastic Network Interface)를 생성/삭제하는데 필요
resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group_role.name
}

# 12-3. ECR(Elastic Container Registry) 읽기 권한
# 워커 노드가 ECR에서 컨테이너 이미지를 pull하기 위해 필요
# 애플리케이션 Pod들이 시작될 때 이미지를 다운로드하는데 사용
resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group_role.name
}

#------------------------------------------------------------------------------
# 13. 노드 그룹 인스턴스 프로파일
#------------------------------------------------------------------------------
# EC2 인스턴스(워커 노드)가 위에서 생성한 IAM 역할을 사용할 수 있도록 하는 프로파일
# EC2는 IAM 역할을 직접 사용할 수 없고, 인스턴스 프로파일을 통해서만 사용 가능
resource "aws_iam_instance_profile" "eks_node_group_profile" {
  name = "${local.project_name}-${local.environment}-eks-node-group-profile"
  role = aws_iam_role.eks_node_group_role.name

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.project_name}-${local.environment}-eks-node-group-profile"
      Purpose     = "EKS Node Group Instance Profile"
      Component   = "EKS-Worker-Nodes"
    }
  )
}

#==============================================================================
# EKS 노드 그룹 (기본/시스템 컴포넌트용)
#==============================================================================

# 🎯 온디맨드 인스턴스 사용 이유:
# 안정성: 시스템 컴포넌트는 항상 실행되어야 함
# 예측 가능성: 스팟 인스턴스는 중단될 수 있어 시스템에 부적합
# 비용 vs 안정성: 시스템 노드는 개수가 적어 비용 영향이 크지 않음
# 🏷️ Taint 설정 이유:
# 역할 분리: 시스템 Pod와 애플리케이션 Pod 분리
# 리소스 보장: 시스템 컴포넌트가 항상 충분한 리소스 확보
# Karpenter 준비: 애플리케이션 Pod들은 Karpenter 노드로 유도 
# -> 애드온들이 안깔려서 실패.
# 📊 스케일링 설정:
# min_size = 1: 최소 비용으로 기본 가용성 보장
# desired_size = 2: 2개 AZ에 분산으로 고가용성
# max_size = 3: 시스템 부하 증가 시 확장 여유

#------------------------------------------------------------------------------
# 14. EKS 관리형 노드 그룹 생성
#------------------------------------------------------------------------------
# 시스템 컴포넌트(Karpenter, CoreDNS, ALB Controller 등)를 실행할 안정적인 노드 그룹
# 온디맨드 인스턴스를 사용하여 시스템 안정성 보장
resource "aws_eks_node_group" "system" {
  # 기본 설정
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.project_name}-${local.environment}-system-nodes"
  node_role_arn   = aws_iam_role.eks_node_group_role.arn
  
  # 노드 배치: 프라이빗 서브넷에만 배치 (보안성)
  # 퍼블릭 IP 자동 할당 안함, NAT Gateway를 통해 인터넷 접근
  subnet_ids = local.private_subnet_ids

  # 인스턴스 타입 설정
  # t3.small: 2vCPU, 2GB RAM - 시스템 컴포넌트에 충분
  instance_types = [
  "t3.small",    # 1순위: 2vCPU, 2GB RAM
  "t3a.small",   # 2순위: 2vCPU, 2GB RAM (AMD 프로세서, 더 저렴)
  #"t2.small",    # 3순위: 1vCPU, 2GB RAM (버스트 타입)
  #"t3.medium",    # 4순위: 2vCPU, 4GB RAM (여유 있음)
  #"t3a.medium"
]
  # 용량 타입: 온디맨드 (안정성 우선)
  # 시스템 컴포넌트는 항상 실행되어야 하므로 스팟 인스턴스 사용 안함
  # capacity_type = "ON_DEMAND"
  capacity_type = "SPOT" 

  # AMI 타입: Amazon Linux 2 EKS 최적화 이미지
  # 기본 설정으로 EKS와 완전 호환되는 이미지 사용
  ami_type = "AL2_x86_64"

  # 노드 그룹 스케일링 설정
  scaling_config {
    # 최소 노드 수: 1개 (비용 절약하면서도 기본 가용성 보장)
    min_size = 1
    
    # 최대 노드 수: 3개 (시스템 컴포넌트가 많아져도 충분)
    max_size = 10
    
    # 초기 노드 수: 1개 (2개 AZ에 각각 1개씩 배치하여 고가용성을 원한다면 2로.)
    desired_size = 2
  }

  # 노드 업데이트 설정
  # 클러스터 업데이트 시 노드를 어떻게 교체할지 설정
  update_config {
    # 업데이트 중 사용 불가능한 노드의 최대 개수
    # 1개씩 순차적으로 업데이트하여 서비스 중단 최소화
    max_unavailable = 1
  }

  # 원격 접근 설정 (선택사항)
  # SSH 키를 지정하여 노드에 직접 접근 가능하도록 설정
  # 디버깅이나 문제 해결 시 유용
  remote_access {
    # EC2 키 페어: 이미 존재하는 키 사용
    ec2_ssh_key = "pumati-full-master"  # 실제 존재하는 키 이름으로 변경 필요
    
    # SSH 접근을 허용할 보안 그룹
    # 노드 보안 그룹을 사용하여 VPC 내에서만 SSH 허용
    source_security_group_ids = [aws_security_group.eks_node_sg.id]
  }

#   # 노드에 적용할 테인트 (Taints) 설정
#   # 시스템 컴포넌트만 이 노드들에 스케줄링되도록 제한
  # taint {
  #   key    = "node-type"
  #   value  = "system"
  #   effect = "NO_SCHEDULE"  # 시스템 Pod이 아닌 일반 Pod는 스케줄링 방지
  # }

  # 노드에 적용할 레이블 설정
  # Kubernetes 스케줄러가 Pod 배치 시 참고할 레이블들
  labels = {
    "node-type"    = "system"           # 노드 타입 구분
    "capacity-type" = "spot"       # 용량 타입 표시
    "role"         = "system-component" # 역할 표시
  }

  # 의존성 설정: 노드 그룹 생성 전에 필요한 리소스들이 준비되어야 함
  depends_on = [
    # IAM 정책들이 모두 연결된 후 노드 그룹 생성
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_policy,
    
    # 클러스터가 활성 상태가 된 후 노드 그룹 생성
    aws_eks_cluster.main
  ]

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.project_name}-${local.environment}-system-node-group"
      Purpose     = "System Components Hosting"
      Component   = "EKS-System-Nodes"
      NodeType    = "System"
      CapacityType = "Spot"
      
      # ✅ Cluster Autoscaler 태그 추가
      "k8s.io/cluster-autoscaler/enabled" = "true"
      "k8s.io/cluster-autoscaler/${aws_eks_cluster.main.name}" = "owned"
    }
  )
}

#------------------------------------------------------------------------------
# 15. 시스템 노드 그룹용 추가 보안 그룹 규칙 (필요시)
#------------------------------------------------------------------------------
# 시스템 컴포넌트들이 필요로 하는 특별한 포트가 있다면 여기에 추가
# 예: Prometheus 메트릭 수집, 로그 수집 등

# 예시: Prometheus가 노드 메트릭을 수집할 수 있도록 9100 포트 허용
resource "aws_security_group_rule" "system_nodes_prometheus" {
  type                     = "ingress"
  from_port                = 9100
  to_port                  = 9100
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_node_sg.id  # 같은 노드 그룹 내에서만
  security_group_id        = aws_security_group.eks_node_sg.id
  description              = "Prometheus node exporter metrics"
}

# Kubernetes API 서버가 kubelet으로부터 메트릭을 수집할 수 있도록 10250 포트 허용
resource "aws_security_group_rule" "system_nodes_kubelet_api" {
  type        = "ingress"
  from_port   = 10250
  to_port     = 10250
  protocol    = "tcp"
  cidr_blocks = local.private_subnet_cidrs  # 프라이빗 서브넷에서만 접근
  security_group_id = aws_security_group.eks_node_sg.id
  description = "Kubelet API for metrics and logs"
}

#==============================================================================
# EKS Add-ons (필수 구성 요소)
#==============================================================================

# 🌐 VPC CNI:
# Pod 네트워킹: Pod들이 VPC IP 주소를 받아 직접 통신
# 보안: VPC 보안 그룹과 NACL 적용 가능
# 성능: 추가 오버헤드 없이 네이티브 AWS 네트워킹 사용
# 🔍 CoreDNS:
# 서비스 디스커버리: service-name.namespace.svc.cluster.local 형태로 서비스 찾기
# 내부 통신: Pod가 서비스 이름으로 다른 Pod에 접근
# 외부 DNS: 클러스터 외부 도메인도 해석 가능
# 🔄 kube-proxy:
# 로드 밸런싱: Service로 들어오는 요청을 여러 Pod에 분산
# 네트워크 라우팅: iptables 또는 IPVS 모드로 트래픽 전달
# Service 추상화: ClusterIP, NodePort, LoadBalancer 타입 지원
# 💾 EBS CSI Driver:
# 영구 저장소: Pod가 재시작되어도 데이터 유지
# 동적 프로비저닝: PVC 생성 시 자동으로 EBS 볼륨 생성
# 스토리지 클래스: 다양한 EBS 볼륨 타입 (gp3, io2 등) 지원
# 🔐 IRSA (IAM Roles for Service Accounts):
# 세밀한 권한 제어: 각 Service Account별로 다른 IAM 권한 부여
# 보안 강화: 노드 전체가 아닌 특정 Pod만 필요한 권한 획득
# AWS 서비스 통합: S3, RDS, Secrets Manager 등에 안전하게 접근

#------------------------------------------------------------------------------
# 16. VPC CNI Add-on
#------------------------------------------------------------------------------
# AWS VPC Container Network Interface - Pod 네트워킹 관리
# Pod들이 VPC IP 주소를 받아 서로 통신할 수 있도록 하는 핵심 컴포넌트
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"
  
  # 최신 버전 사용 (AWS가 관리하는 안정적인 버전)
  # resolve_conflicts = "OVERWRITE"로 설정하여 기존 설정을 덮어씀
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  
  # VPC CNI가 IP 주소를 관리하기 위해 필요한 권한
  # 이미 노드 그룹 역할에 AmazonEKS_CNI_Policy가 연결되어 있음
  depends_on = [
    aws_eks_node_group.system,
    aws_iam_role_policy_attachment.eks_cni_policy
  ]

  tags = merge(
    local.common_tags,
    {
      Name      = "${local.project_name}-${local.environment}-vpc-cni"
      Purpose   = "Pod Networking"
      Component = "EKS-Networking"
    }
  )
}

#------------------------------------------------------------------------------
# 17. CoreDNS Add-on (EKS 1.28 호환 버전)
#------------------------------------------------------------------------------
# Kubernetes 클러스터 내부 DNS 서비스
# Pod들이 서비스 이름으로 서로를 찾을 수 있도록 하는 DNS 해석 서비스
resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"
  
  # EKS 1.28과 호환되는 CoreDNS 버전
  addon_version = "v1.10.1-eksbuild.18"
  
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  
  # VPC CNI가 먼저 설치되어야 CoreDNS Pod들이 네트워킹 가능
  depends_on = [
    aws_eks_addon.vpc_cni,
    aws_eks_node_group.system
  ]

  tags = merge(
    local.common_tags,
    {
      Name      = "${local.project_name}-${local.environment}-coredns"
      Purpose   = "Internal DNS Resolution"
      Component = "EKS-DNS"
    }
  )
}

#------------------------------------------------------------------------------
# 18. kube-proxy Add-on
#------------------------------------------------------------------------------
# Kubernetes 네트워크 프록시 - Service 라우팅 담당
# Service로 들어오는 트래픽을 적절한 Pod로 전달하는 네트워크 프록시
resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"
  
  # kube-proxy 충돌 해결
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  
  # 노드 그룹이 준비된 후 설치
  depends_on = [
    aws_eks_node_group.system
  ]

  tags = merge(
    local.common_tags,
    {
      Name      = "${local.project_name}-${local.environment}-kube-proxy"
      Purpose   = "Service Traffic Routing"
      Component = "EKS-Proxy"
    }
  )
}

#------------------------------------------------------------------------------
# 19. EBS CSI Driver를 위한 IAM 역할 생성
#------------------------------------------------------------------------------
# Amazon EBS Container Storage Interface Driver용 IAM 역할
# Pod들이 EBS 볼륨을 영구 저장소로 사용할 수 있도록 하는 드라이버에 필요한 권한

# 현재 AWS 계정 정보 가져오기 (IAM 역할 ARN에 필요)
data "aws_caller_identity" "current" {}

resource "aws_iam_role" "ebs_csi_driver_role" {
  name = "${local.project_name}-${local.environment}-ebs-csi-driver-role"

  # EKS의 Service Account가 이 역할을 assume할 수 있도록 설정
  # IRSA (IAM Roles for Service Accounts) 패턴 사용
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name      = "${local.project_name}-${local.environment}-ebs-csi-driver-role"
      Purpose   = "EBS Volume Management"
      Component = "EKS-Storage"
    }
  )
}

#------------------------------------------------------------------------------
# 20. EBS CSI Driver에 필요한 AWS 관리형 정책 연결
#------------------------------------------------------------------------------
# EBS CSI Driver가 EBS 볼륨을 생성, 삭제, 연결, 분리하는데 필요한 권한
resource "aws_iam_role_policy_attachment" "ebs_csi_driver_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver_role.name
}

#------------------------------------------------------------------------------
# 21. EBS CSI Driver Add-on 설치
#------------------------------------------------------------------------------
# Amazon EBS Container Storage Interface Driver Add-on
# 데이터베이스, 파일 저장 등에 필요한 영구 볼륨 지원
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "aws-ebs-csi-driver"
  
  # EBS CSI Driver가 사용할 Service Account의 IAM 역할 지정
  service_account_role_arn = aws_iam_role.ebs_csi_driver_role.arn
  
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  
  # IAM 역할과 정책이 연결된 후 설치
  depends_on = [
    aws_iam_role_policy_attachment.ebs_csi_driver_policy,
    aws_eks_node_group.system
  ]

  tags = merge(
    local.common_tags,
    {
      Name      = "${local.project_name}-${local.environment}-ebs-csi-driver"
      Purpose   = "Persistent Volume Support"
      Component = "EKS-Storage"
    }
  )
}

#------------------------------------------------------------------------------
# 9. EKS OIDC Identity Provider 생성
#------------------------------------------------------------------------------
# IRSA (IAM Roles for Service Accounts) 기능을 위해 필요
# Service Account에 IAM 역할을 연결하여 세밀한 권한 제어 가능
data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks_oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-eks-oidc-provider"
      Component = "EKS-OIDC"
    }
  )
}
