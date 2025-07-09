#==============================================================================
# AWS ElastiCache Redis 클러스터 설정
#==============================================================================

# 🎯 Redis 클러스터 목적:
# 세션 관리: Spring Boot 애플리케이션의 세션 저장소로 사용
# 캐싱: 데이터베이스 쿼리 결과 캐싱으로 성능 향상
# OAuth 세션: 카카오 로그인 세션 정보 안전하게 저장
# 고가용성: Multi-AZ 배포로 서비스 중단 최소화

#------------------------------------------------------------------------------
# 1. Redis 서브넷 그룹 생성
#------------------------------------------------------------------------------
# ElastiCache가 사용할 서브넷들을 그룹으로 묶어서 정의
# Private 서브넷에만 배치하여 보안 강화
resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "${local.project_name}-${local.environment}-redis-subnet-group"
  subnet_ids = local.private_subnet_ids  # Private 서브넷들에만 배치

  tags = merge(
    local.common_tags,
    {
      Name      = "${local.project_name}-${local.environment}-redis-subnet-group"
      Purpose   = "Redis Subnet Group"
      Component = "ElastiCache"
    }
  )
}

#------------------------------------------------------------------------------
# 2. Redis 보안 그룹 생성
#------------------------------------------------------------------------------
# Redis 클러스터에 대한 네트워크 접근 제어
# EKS 노드들만 Redis에 접근할 수 있도록 제한
resource "aws_security_group" "redis_sg" {
  name        = "${local.project_name}-${local.environment}-redis-sg"
  description = "Security group for ElastiCache Redis cluster"
  vpc_id      = local.vpc_id

  # 인바운드 규칙: EKS 노드들에서만 Redis 포트(6379) 접근 허용
  ingress {
    description = "Redis access from EKS nodes"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = local.private_subnet_cidrs  # Private 서브넷에서만 접근 허용
  }

  # 아웃바운드 규칙: 모든 트래픽 허용 (기본적으로 필요)
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
      Name      = "${local.project_name}-${local.environment}-redis-sg"
      Purpose   = "Redis Security Group"
      Component = "ElastiCache"
    }
  )
}

#------------------------------------------------------------------------------
# 3. Redis 파라미터 그룹 생성 (선택사항)
#------------------------------------------------------------------------------
# Redis 설정을 커스터마이징하기 위한 파라미터 그룹
# 메모리 정책, 타임아웃 등을 애플리케이션에 맞게 조정
resource "aws_elasticache_parameter_group" "redis_params" {
  family = "redis7.x"  # Redis 7.x 버전 사용
  name   = "${local.project_name}-${local.environment}-redis-params"

  # 메모리 정책 설정 (메모리 부족 시 가장 오래된 키 삭제)
  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  # 타임아웃 설정 (30분 = 1800초)
  parameter {
    name  = "timeout"
    value = "1800"
  }

  tags = merge(
    local.common_tags,
    {
      Name      = "${local.project_name}-${local.environment}-redis-params"
      Purpose   = "Redis Parameter Group"
      Component = "ElastiCache"
    }
  )
}

#------------------------------------------------------------------------------
# 4. ElastiCache Redis 클러스터 생성
#------------------------------------------------------------------------------
# 실제 Redis 클러스터 생성
# 개발 환경용 단일 노드 구성 (비용 최적화)
resource "aws_elasticache_replication_group" "redis_cluster" {
  replication_group_id       = "${local.project_name}-${local.environment}-redis"
  description                = "Redis cluster for ${local.project_name} ${local.environment}"
  
  # 클러스터 설정
  node_type                  = "cache.t3.micro"  # 개발환경용 최소 사양 (프로덕션에서는 더 큰 사양 사용)
  port                       = 6379
  parameter_group_name       = aws_elasticache_parameter_group.redis_params.name
  
  # 복제 설정
  num_cache_clusters         = 1  # 개발환경: 단일 노드 (프로덕션: 2개 이상 권장)
  
  # 네트워크 설정
  subnet_group_name          = aws_elasticache_subnet_group.redis_subnet_group.name
  security_group_ids         = [aws_security_group.redis_sg.id]
  
  # 엔진 설정
  engine_version             = "7.0"  # Redis 7.0 버전 사용
  
  # 백업 및 유지보수 설정
  snapshot_retention_limit   = 1      # 개발환경: 스냅샷 1일 보관
  snapshot_window           = "03:00-05:00"  # 새벽 3-5시 백업 (한국시간 기준 오후 12-2시)
  maintenance_window        = "sun:05:00-sun:06:00"  # 일요일 새벽 5-6시 유지보수
  
  # 보안 설정
  at_rest_encryption_enabled = true   # 저장 데이터 암호화
  transit_encryption_enabled = false  # 전송 암호화 비활성화 (VPC 내부 통신이므로)
  
  # 로그 설정
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_slow_log.name
    destination_type = "cloudwatch-logs"
    log_format       = "text"
    log_type         = "slow-log"
  }

  tags = merge(
    local.common_tags,
    {
      Name      = "${local.project_name}-${local.environment}-redis-cluster"
      Purpose   = "Redis Cluster"
      Component = "ElastiCache"
    }
  )
}

#------------------------------------------------------------------------------
# 5. CloudWatch 로그 그룹 (Redis 슬로우 로그용)
#------------------------------------------------------------------------------
# Redis 성능 모니터링을 위한 슬로우 로그 저장소
resource "aws_cloudwatch_log_group" "redis_slow_log" {
  name              = "/aws/elasticache/redis/${local.project_name}-${local.environment}"
  retention_in_days = 7  # 개발환경: 7일 보관

  tags = merge(
    local.common_tags,
    {
      Name      = "${local.project_name}-${local.environment}-redis-logs"
      Purpose   = "Redis CloudWatch Logs"
      Component = "ElastiCache"
    }
  )
}

#------------------------------------------------------------------------------
# 6. Redis 연결 정보를 Kubernetes Secret으로 저장
#------------------------------------------------------------------------------
# 백엔드 애플리케이션이 Redis에 연결할 수 있도록 연결 정보 제공
resource "kubernetes_secret" "redis_connection" {
  metadata {
    name      = "redis-connection"
    namespace = "pumati"  # 백엔드 애플리케이션이 배포되는 네임스페이스
    
    labels = {
      "app.kubernetes.io/name"      = "redis-connection"
      "app.kubernetes.io/component" = "database"
      "app.kubernetes.io/part-of"   = "pumati"
    }
  }

  # Redis 연결 정보
  data = {
    REDIS_HOST = aws_elasticache_replication_group.redis_cluster.primary_endpoint_address
    REDIS_PORT = tostring(aws_elasticache_replication_group.redis_cluster.port)
    REDIS_URL  = "redis://${aws_elasticache_replication_group.redis_cluster.primary_endpoint_address}:${aws_elasticache_replication_group.redis_cluster.port}"
  }

  type = "Opaque"
}
