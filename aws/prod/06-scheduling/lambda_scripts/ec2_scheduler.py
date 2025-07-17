import boto3
import os
import json
import urllib.request

ec2 = boto3.client('ec2')
secrets_client = boto3.client('secretsmanager')

INSTANCE_IDS = os.environ['INSTANCE_IDS'].split(",")
SECRET_NAME = os.environ['DISCORD_WEBHOOK_URL']

def get_webhook_url(secret_name):
    # Secrets Manager에서 시크릿 가져오기 (.env 형식 전용 파싱)
    response = secrets_client.get_secret_value(SecretId=secret_name)
    secret_string = response['SecretString']
    secret_dict = dict(
        line.split("=", 1) for line in secret_string.splitlines() if "=" in line
    )
    return secret_dict.get("DISCORD_WEBHOOK_URL")

def send_discord_message(message):
    try:
        webhook_url = get_webhook_url(SECRET_NAME)
        if not webhook_url:
            print("❌ DISCORD_WEBHOOK_URL not found in secret")
            return
        data = { "content": message }
        req = urllib.request.Request(
            webhook_url,
            data=json.dumps(data).encode("utf-8"),
            headers={"Content-Type": "application/json"}
        )
        urllib.request.urlopen(req)
    except Exception as e:
        print(f"❌ Failed to send Discord message: {e}")

def lambda_handler(event, context):
    action = event.get("action")

    if action == "start":
        ec2.start_instances(InstanceIds=INSTANCE_IDS)
        msg = f"✅ Started EC2 instances: {INSTANCE_IDS}"
    elif action == "stop":
        ec2.stop_instances(InstanceIds=INSTANCE_IDS)
        msg = f"🛑 Stopped EC2 instances: {INSTANCE_IDS}"
    else:
        msg = f"⚠️ Unknown action: {action}"

    send_discord_message(msg)
    return msg
