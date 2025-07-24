#!/bin/bash
# 백엔드 서버 설정 스크립트 (커스텀 AMI 사용)
# Project: ${project_name}
# Environment: ${environment}

# 로그 설정
LOG_FILE="/var/log/backend-setup.log"
exec > >(tee -a $LOG_FILE)
exec 2>&1

echo "=== 백엔드 서버 설정 시작: $(date) ==="

# 환경 변수 설정
export PROJECT_NAME="${project_name}"
export ENVIRONMENT="${environment}"
export APP_PORT="${app_port}"
export LOG_GROUP_NAME="${log_group_name}"
export MONGODB_URI="${mongodb_uri}"

# CloudWatch Agent 설정 파일 생성
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
    "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "cwagent"
    },
    "metrics": {
        "namespace": "LoadTest/Backend",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "diskio": {
                "measurement": [
                    "io_time",
                    "read_bytes",
                    "write_bytes",
                    "reads",
                    "writes"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent",
                    "mem_total",
                    "mem_used"
                ],
                "metrics_collection_interval": 60
            },
            "netstat": {
                "measurement": [
                    "tcp_established",
                    "tcp_time_wait"
                ],
                "metrics_collection_interval": 60
            }
        }
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/backend-app/*.log",
                        "log_group_name": "${log_group_name}",
                        "log_stream_name": "{instance_id}-app",
                        "timezone": "UTC"
                    },
                    {
                        "file_path": "/var/log/backend-setup.log",
                        "log_group_name": "${log_group_name}",
                        "log_stream_name": "{instance_id}-setup",
                        "timezone": "UTC"
                    }
                ]
            }
        }
    }
}
EOF

# CloudWatch Agent 시작 (IAM 역할 없이)
echo "CloudWatch Agent 시작 중... (제한된 권한으로 동작)"
# IAM 역할이 없으므로 CloudWatch Agent는 제한된 기능으로만 동작
# 메트릭 수집은 시도하지만 로그 전송은 실패할 수 있음
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s || echo "CloudWatch Agent 시작 실패 (IAM 권한 부족)"

# 애플리케이션 환경변수 파일 생성 (커스텀 AMI에서 사용)
mkdir -p /opt/app
cat > /opt/app/.env << EOF
NODE_ENV=production
PORT=${app_port}
MONGODB_URI=${mongodb_uri}
PROJECT_NAME=${project_name}
ENVIRONMENT=${environment}
AWS_REGION=ap-northeast-2
LOG_LEVEL=info
EOF

# PM2 프로세스 재시작 (커스텀 AMI에 이미 설정되어 있다고 가정)
echo "백엔드 애플리케이션 시작 중..."
cd /opt/app

# PM2로 애플리케이션 시작/재시작
pm2 restart backend-app || pm2 start ecosystem.config.js --name backend-app

# PM2 startup 설정
pm2 startup
pm2 save

# Health Check 엔드포인트 확인
echo "Health Check 대기 중..."
for i in {1..30}; do
    if curl -f http://localhost:${app_port}/health >/dev/null 2>&1; then
        echo "백엔드 애플리케이션 정상 시작 확인!"
        break
    fi
    echo "Health Check 대기 중... ($i/30)"
    sleep 10
done

# 시스템 정보 출력
echo "=== 시스템 정보 ==="
echo "Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
echo "Private IP: $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
echo "App Port: ${app_port}"
echo "MongoDB URI: ${mongodb_uri}"
echo "PM2 Status:"
pm2 status

echo "=== 백엔드 서버 설정 완료: $(date) ===" 