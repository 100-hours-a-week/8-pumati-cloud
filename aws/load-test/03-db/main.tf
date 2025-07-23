#==============================================================================
# DocumentDB (MongoDB 호환) - 부하 테스트 환경
#==============================================================================
# 🎯 부하 테스트용 MongoDB 구성:
# - 비용 최적화: 백업 최소화, 최소 인스턴스 사양
# - 마스터 1개 + 읽기 전용 2개 구성 
# - VPC 내 보안 그룹으로 접근 제어

#-------------------------------
# 1. DocumentDB용 보안 그룹 생성
#-------------------------------
resource "aws_security_group" "documentdb_sg" {
  name_prefix = "${local.project_name}-${local.environment}-documentdb-"
  description = "Security group for DocumentDB cluster (MongoDB compatible)"
  vpc_id      = local.vpc_id

  # DocumentDB 포트 (27017) - VPC 내부에서만 접근 허용
  ingress {
    description = "DocumentDB access from VPC"
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr_block]
  }

  # 모든 아웃바운드 트래픽 허용
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
      Name        = "${local.project_name}-${local.environment}-documentdb-sg"
      Type        = "Database Security Group"
      Purpose     = "Load Test DocumentDB Access"
      Environment = local.environment
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

#-------------------------------
# 2. DocumentDB 클러스터 파라미터 그룹 (성능 최적화)
#-------------------------------
resource "aws_docdb_cluster_parameter_group" "main" {
  family      = "docdb5.0"
  name        = "${local.project_name}-${local.environment}-docdb-params"
  description = "DocumentDB cluster parameter group for load testing"

  # 부하 테스트용 성능 최적화 파라미터
  parameter {
    name  = "tls"
    value = "disabled"  # 부하 테스트용으로 TLS 비활성화 (성능 향상)
  }

  parameter {
    name  = "ttl_monitor_enabled"
    value = "enabled"   # TTL 모니터링 활성화
  }

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.project_name}-${local.environment}-docdb-params"
      Type        = "Database Parameter Group"
      Purpose     = "Load Test Optimization"
      Environment = local.environment
    }
  )
}

#-------------------------------
# 3. DocumentDB 서브넷 그룹
#-------------------------------
resource "aws_docdb_subnet_group" "main" {
  name       = "${local.project_name}-${local.environment}-docdb-subnet-group"
  subnet_ids = local.public_subnet_ids  # 02-network에서 가져온 퍼블릭 서브넷 사용

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.project_name}-${local.environment}-docdb-subnet-group"
      Type        = "Database Subnet Group"
      Purpose     = "Load Test DocumentDB"
      Environment = local.environment
    }
  )
}

#-------------------------------
# 4. DocumentDB 클러스터 생성 (마스터)
#-------------------------------
resource "aws_docdb_cluster" "main" {
  cluster_identifier              = "${local.project_name}-${local.environment}-docdb-cluster"
  engine                         = "docdb"
  engine_version                 = "5.0.0"  # 최신 버전 사용
  master_username                = "admin"
  master_password                = var.db_password
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.main.name
  db_subnet_group_name           = aws_docdb_subnet_group.main.name
  vpc_security_group_ids         = [aws_security_group.documentdb_sg.id]

  # 🎯 부하 테스트용 비용 최적화 설정
  backup_retention_period    = 1           # 최소 백업 기간 (1일)
  preferred_backup_window    = "03:00-04:00" # 새벽 시간대 백업
  preferred_maintenance_window = "sun:04:00-sun:05:00" # 일요일 새벽 유지보수
  skip_final_snapshot       = true         # 최종 스냅샷 건너뛰기 (비용 절약)
  deletion_protection       = false        # 삭제 보호 비활성화 (부하 테스트 완료 후 쉽게 삭제)
  
  # 스토리지 암호화 (보안)
  storage_encrypted = true
  
  # 로그 설정 (모니터링용)
  enabled_cloudwatch_logs_exports = ["audit", "profiler"]

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.project_name}-${local.environment}-docdb-cluster"
      Type        = "Database Cluster"
      Purpose     = "Load Test MongoDB"
      Environment = local.environment
      Engine      = "DocumentDB"
    }
  )
}

#-------------------------------
# 5. DocumentDB 클러스터 인스턴스들 (마스터 + 읽기 전용)
#-------------------------------

# 마스터 인스턴스 (쓰기 가능)
resource "aws_docdb_cluster_instance" "primary" {
  identifier         = "${local.project_name}-${local.environment}-docdb-primary"
  cluster_identifier = aws_docdb_cluster.main.id
  instance_class     = "db.t3.medium"  # DocumentDB 최소 지원 사양
  
  tags = merge(
    local.common_tags,
    {
      Name        = "${local.project_name}-${local.environment}-docdb-primary"
      Type        = "Database Instance"
      Role        = "Primary"
      Purpose     = "Load Test Write Operations"
      Environment = local.environment
    }
  )
}

# 읽기 전용 인스턴스 1
resource "aws_docdb_cluster_instance" "reader_1" {
  identifier         = "${local.project_name}-${local.environment}-docdb-reader-1"
  cluster_identifier = aws_docdb_cluster.main.id
  instance_class     = "db.t3.medium"
  
  tags = merge(
    local.common_tags,
    {
      Name        = "${local.project_name}-${local.environment}-docdb-reader-1"
      Type        = "Database Instance"
      Role        = "Reader"
      Purpose     = "Load Test Read Operations"
      Environment = local.environment
    }
  )
}

# 읽기 전용 인스턴스 2
resource "aws_docdb_cluster_instance" "reader_2" {
  identifier         = "${local.project_name}-${local.environment}-docdb-reader-2"
  cluster_identifier = aws_docdb_cluster.main.id
  instance_class     = "db.t3.medium"
  
  tags = merge(
    local.common_tags,
    {
      Name        = "${local.project_name}-${local.environment}-docdb-reader-2"
      Type        = "Database Instance"
      Role        = "Reader"
      Purpose     = "Load Test Read Operations"
      Environment = local.environment
    }
  )
}

#-------------------------------
# 6. CloudWatch 로그 그룹 생성 (모니터링용)
#-------------------------------
resource "aws_cloudwatch_log_group" "documentdb_audit" {
  name              = "/aws/docdb/${local.project_name}-${local.environment}/audit"
  retention_in_days = 3  # 부하 테스트용으로 3일만 보관 (비용 절약)

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.project_name}-${local.environment}-docdb-audit-logs"
      Type        = "Database Logs"
      Purpose     = "Load Test Monitoring"
      Environment = local.environment
    }
  )
}

resource "aws_cloudwatch_log_group" "documentdb_profiler" {
  name              = "/aws/docdb/${local.project_name}-${local.environment}/profiler"
  retention_in_days = 3  # 부하 테스트용으로 3일만 보관

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.project_name}-${local.environment}-docdb-profiler-logs"
      Type        = "Database Logs"
      Purpose     = "Load Test Performance Analysis"
      Environment = local.environment
    }
  )
}

#-------------------------------
# 7. 기본 알람 설정 (성능 모니터링)
#-------------------------------
resource "aws_cloudwatch_metric_alarm" "documentdb_cpu_utilization" {
  alarm_name          = "${local.project_name}-${local.environment}-docdb-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/DocDB"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "DocumentDB CPU utilization is too high"
  alarm_actions       = [] # 부하 테스트 환경이므로 알림 액션 없음

  dimensions = {
    DBClusterIdentifier = aws_docdb_cluster.main.cluster_identifier
  }

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.project_name}-${local.environment}-docdb-cpu-alarm"
      Type        = "Database Monitoring"
      Purpose     = "Load Test Performance Alert"
      Environment = local.environment
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "documentdb_read_latency" {
  alarm_name          = "${local.project_name}-${local.environment}-docdb-read-latency-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ReadLatency"
  namespace           = "AWS/DocDB"
  period              = "300"
  statistic           = "Average"
  threshold           = "0.5"  # 500ms
  alarm_description   = "DocumentDB read latency is too high"
  alarm_actions       = []

  dimensions = {
    DBClusterIdentifier = aws_docdb_cluster.main.cluster_identifier
  }

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.project_name}-${local.environment}-docdb-read-latency-alarm"
      Type        = "Database Monitoring"
      Purpose     = "Load Test Performance Alert"
      Environment = local.environment
    }
  )
}
