# DocumentDB 클러스터 출력
output "documentdb_cluster_endpoint" {
  description = "DocumentDB 클러스터 엔드포인트 (쓰기용)"
  value       = aws_docdb_cluster.main.endpoint
}

output "documentdb_cluster_reader_endpoint" {
  description = "DocumentDB 클러스터 읽기 전용 엔드포인트"
  value       = aws_docdb_cluster.main.reader_endpoint
}

output "documentdb_cluster_identifier" {
  description = "DocumentDB 클러스터 식별자"
  value       = aws_docdb_cluster.main.cluster_identifier
}

output "documentdb_cluster_arn" {
  description = "DocumentDB 클러스터 ARN"
  value       = aws_docdb_cluster.main.arn
}

output "documentdb_port" {
  description = "DocumentDB 포트 번호"
  value       = aws_docdb_cluster.main.port
}

# DocumentDB 인스턴스 출력
output "documentdb_primary_instance_id" {
  description = "DocumentDB 마스터 인스턴스 ID"
  value       = aws_docdb_cluster_instance.primary.identifier
}

output "documentdb_reader_instance_ids" {
  description = "DocumentDB 읽기 전용 인스턴스 ID 목록"
  value       = [
    aws_docdb_cluster_instance.reader_1.identifier,
    aws_docdb_cluster_instance.reader_2.identifier
  ]
}

# 보안 그룹 출력
output "documentdb_security_group_id" {
  description = "DocumentDB 보안 그룹 ID"
  value       = aws_security_group.documentdb_sg.id
}

# 서브넷 그룹 출력
output "documentdb_subnet_group_name" {
  description = "DocumentDB 서브넷 그룹 이름"
  value       = aws_docdb_subnet_group.main.name
}

# 파라미터 그룹 출력
output "documentdb_parameter_group_name" {
  description = "DocumentDB 클러스터 파라미터 그룹 이름"
  value       = aws_docdb_cluster_parameter_group.main.name
}

# CloudWatch 로그 그룹 출력
output "documentdb_audit_log_group_name" {
  description = "DocumentDB 감사 로그 그룹 이름"
  value       = aws_cloudwatch_log_group.documentdb_audit.name
}

output "documentdb_profiler_log_group_name" {
  description = "DocumentDB 프로파일러 로그 그룹 이름"
  value       = aws_cloudwatch_log_group.documentdb_profiler.name
}

# 애플리케이션에서 사용할 연결 정보
output "mongodb_connection_info" {
  description = "애플리케이션에서 사용할 MongoDB 연결 정보"
  value = {
    primary_endpoint = aws_docdb_cluster.main.endpoint
    reader_endpoint  = aws_docdb_cluster.main.reader_endpoint
    port            = aws_docdb_cluster.main.port
    username        = aws_docdb_cluster.main.master_username
    database_name   = "pumati_load_test"  # 기본 데이터베이스명
  }
  sensitive = false
}

# 연결 문자열 (비밀번호 제외)
output "mongodb_connection_string_template" {
  description = "MongoDB 연결 문자열 템플릿 (비밀번호는 별도 관리)"
  value       = "mongodb://admin:<PASSWORD>@${aws_docdb_cluster.main.endpoint}:${aws_docdb_cluster.main.port}/pumati_load_test?ssl=false&replicaSet=rs0&readPreference=secondaryPreferred"
}
