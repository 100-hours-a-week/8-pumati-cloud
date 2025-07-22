import boto3
import os
import logging

# [1] 로거 설정
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# [2] AWS 클라이언트 초기화
ec2 = boto3.client('ec2')

# [3] 환경변수 로딩
INSTANCE_IDS = os.environ['INSTANCE_IDS'].split(",")

# [4] Lambda 핸들러
def lambda_handler(event, context):
    logger.info(f"🔍 Received event: {event}")
    action = event.get("action")

    if action == "start":
        ec2.start_instances(InstanceIds=INSTANCE_IDS)
        msg = f"✅ Started EC2 instances: {INSTANCE_IDS}"
    elif action == "stop":
        ec2.stop_instances(InstanceIds=INSTANCE_IDS)
        msg = f"🛑 Stopped EC2 instances: {INSTANCE_IDS}"
    else:
        msg = f"⚠️ Unknown action: {action}"

    logger.info(msg)
    return msg
