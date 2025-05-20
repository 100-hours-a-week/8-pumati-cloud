#-------------------------------
# 1. MySQL용 보안 그룹 생성
#-------------------------------
resource "aws_security_group" "mysql_sg" {
  name        = "${local.project_name}-${local.environment}-mysql-sg"
  description = "Security group for MySQL EC2 instance"
  vpc_id      = local.vpc_id

  # SSH 접속 허용 (22번 포트)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH 접속용"
  }

  # MySQL 접속 허용 (3306번 포트)
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"]  # VPC 내부에서만 접속 가능
    description = "MySQL 접속용"
  }

  # 모든 아웃바운드 트래픽 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "모든 아웃바운드 트래픽 허용"
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-mysql-sg"
  })
}

#-------------------------------
# 2. MySQL용 EC2 인스턴스 생성
#-------------------------------
resource "aws_instance" "mysql" {
  ami                    = "ami-0f3a440bbcff3d043"  # Amazon Linux 2023 AMI (ap-northeast-2)
  instance_type          = "t3.small"  # 소규모 데이터베이스에 적합한 사이즈
  key_name               = "pumati-full-master"  # 키 페어 이름
  subnet_id              = local.subnet_id
  vpc_security_group_ids = [aws_security_group.mysql_sg.id]

  # EBS 루트 볼륨 설정
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20  # 20GB
    delete_on_termination = true
    encrypted             = true

    tags = merge(local.common_tags, {
      Name = "${local.project_name}-${local.environment}-mysql-root-volume"
    })
  }

  # MySQL을 설치하기 위한 사용자 데이터 스크립트
  user_data = <<-EOF
    #!/bin/bash
    # 시스템 업데이트
    dnf update -y
    
    # MySQL 설치
    dnf install -y mysql-server
    
    # MySQL 서비스 시작 및 자동 시작 설정
    systemctl start mysqld
    systemctl enable mysqld
    
    # MySQL 초기 설정
    # 루트 비밀번호 설정 (실제 환경에서는 보안을 위해 다른 방법 사용 권장)
    mysql_secure_installation --password=Pumati!2023 --use-default
    
    # 데이터베이스 및 사용자 생성
    mysql -u root -pPumati!2023 <<MYSQL_SCRIPT
    CREATE DATABASE pumati;
    CREATE USER 'pumati_user'@'%' IDENTIFIED BY 'Pumati!2023';
    GRANT ALL PRIVILEGES ON pumati.* TO 'pumati_user'@'%';
    FLUSH PRIVILEGES;
    MYSQL_SCRIPT
    
    # MySQL 원격 접속 허용 설정
    sed -i 's/bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/' /etc/my.cnf
    
    # MySQL 재시작
    systemctl restart mysqld
  EOF

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-mysql"
  })
}

#-------------------------------
# 3. MySQL용 탄력적 IP 할당
#-------------------------------
resource "aws_eip" "mysql" {
  domain   = "vpc"
  instance = aws_instance.mysql.id
  
  tags = merge(local.common_tags, {
    Name = "${local.project_name}-${local.environment}-mysql-eip"
  })
}
