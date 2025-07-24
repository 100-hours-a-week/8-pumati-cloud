# load-test-dev/04-redis/outputs.tf
# Redis 마스터-슬레이브 출력 정보

# ===============================
# Redis 마스터 정보
# ===============================

output "redis_master_public_ip" {
  description = "Redis 마스터 공용 IP"
  value       = aws_instance.redis_master.public_ip
}

output "redis_master_private_ip" {
  description = "Redis 마스터 사설 IP"
  value       = aws_instance.redis_master.private_ip
}

output "redis_master_instance_id" {
  description = "Redis 마스터 인스턴스 ID"
  value       = aws_instance.redis_master.id
}

# ===============================
# Redis 슬레이브 정보
# ===============================

output "redis_slave_public_ip" {
  description = "Redis 슬레이브 공용 IP"
  value       = aws_instance.redis_slave.public_ip
}

output "redis_slave_private_ip" {
  description = "Redis 슬레이브 사설 IP"
  value       = aws_instance.redis_slave.private_ip
}

output "redis_slave_instance_id" {
  description = "Redis 슬레이브 인스턴스 ID"
  value       = aws_instance.redis_slave.id
}

# ===============================
# 연결 정보
# ===============================

output "redis_connection_info" {
  description = "Redis 클러스터 연결 정보"
  value = {
    master = {
      public_ip  = aws_instance.redis_master.public_ip
      private_ip = aws_instance.redis_master.private_ip
      port       = 6379
      role       = "master"
    }
    slave = {
      public_ip  = aws_instance.redis_slave.public_ip
      private_ip = aws_instance.redis_slave.private_ip
      port       = 6379
      role       = "slave"
    }
  }
}

# ===============================
# 백엔드 애플리케이션용 환경변수
# ===============================

output "redis_env_vars" {
  description = "백엔드 애플리케이션용 Redis 환경변수"
  value = {
    REDIS_MASTER_HOST = aws_instance.redis_master.private_ip
    REDIS_MASTER_PORT = "6379"
    REDIS_SLAVE_HOST  = aws_instance.redis_slave.private_ip
    REDIS_SLAVE_PORT  = "6379"
    REDIS_MASTER_URL  = "redis://${aws_instance.redis_master.private_ip}:6379"
    REDIS_SLAVE_URL   = "redis://${aws_instance.redis_slave.private_ip}:6379"
  }
}

# ===============================
# SSH 연결 명령어
# ===============================

output "ssh_commands" {
  description = "SSH 연결 명령어"
  value = {
    master = "ssh -i ~/.ssh/8-ktb-chat-keypair.pem ubuntu@${aws_instance.redis_master.public_ip}"
    slave  = "ssh -i ~/.ssh/8-ktb-chat-keypair.pem ubuntu@${aws_instance.redis_slave.public_ip}"
  }
}

# ===============================
# Redis 테스트 명령어
# ===============================

output "redis_test_commands" {
  description = "Redis 연결 및 테스트 명령어"
  value = {
    master_ping = "redis-cli -h ${aws_instance.redis_master.private_ip} ping"
    slave_ping  = "redis-cli -h ${aws_instance.redis_slave.private_ip} ping"
    
    # 마스터에 쓰기 테스트
    write_test = "redis-cli -h ${aws_instance.redis_master.private_ip} set test_key 'Hello Redis'"
    
    # 슬레이브에서 읽기 테스트
    read_test = "redis-cli -h ${aws_instance.redis_slave.private_ip} get test_key"
    
    # 복제 상태 확인
    replication_info = {
      master = "redis-cli -h ${aws_instance.redis_master.private_ip} info replication"
      slave  = "redis-cli -h ${aws_instance.redis_slave.private_ip} info replication"
    }
  }
}

# ===============================
# 모니터링 정보
# ===============================

output "monitoring_info" {
  description = "Redis 모니터링 정보"
  value = {
    cloudwatch_log_groups = {
      master = "/aws/ec2/redis-master"
      slave  = "/aws/ec2/redis-slave"
    }
    
    cloudwatch_namespace = "Redis/LoadTest"
    
    monitoring_scripts = {
      status_check     = "redis-monitor.sh"
      replication_test = "redis-replication-test.sh"
    }
  }
} 