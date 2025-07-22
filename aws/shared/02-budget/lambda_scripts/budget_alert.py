import os
import json
import urllib.request
import boto3

secretsmanager = boto3.client('secretsmanager')
SECRET_NAME = os.environ["DISCORD_SECRET_NAME"]

def lambda_handler(event, context):
    secret_value = secretsmanager.get_secret_value(SecretId=SECRET_NAME)
    secret = json.loads(secret_value["SecretString"])
    webhook_url = secret["DISCORD_WEBHOOK_URL"]

    for record in event["Records"]:
        msg = record["Sns"]["Message"]
        content = f"[💰 AWS Budget Alert]\n{msg}"

        payload = json.dumps({ "content": content }).encode("utf-8")
        req = urllib.request.Request(
            webhook_url,
            data=payload,
            headers={ "Content-Type": "application/json" }
        )

        with urllib.request.urlopen(req) as res:
            print("Discord Response:", res.status)

    return { "status": "ok" }
