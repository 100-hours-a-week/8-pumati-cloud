#---------------------------------------------------------------------------------------------------------------------
# 1. Discord Secrets Manager
#---------------------------------------------------------------------------------------------------------------------
module "discord_env_secret_prod" {
  source = "../../common/module/secretsmanager"

  project_name  = local.project_name
  environment   = local.environment
  tags          = local.common_tags

  service_name  = "discord-webhook"
  env_file_path = "../../common/envs/discord/.env"
  kms_key_id    = "arn:aws:kms:ap-northeast-2:236450698266:key/93a8affe-a6f3-4f22-bdcc-dfafac23e42d"
}

#---------------------------------------------------------------------------------------------------------------------
# 2. Lambda Scheduler Role
#---------------------------------------------------------------------------------------------------------------------
module "lambda_scheduler_role" {
  source                  = "../../common/module/iam_role"
  project_name            = local.project_name
  environment             = local.environment
  service_name            = "ec2-scheduler"
  assume_role_service     = "lambda.amazonaws.com"
  instance_profile_enabled = false
  tags                     = local.common_tags

  enable_inline_policy  = true
  enable_managed_policy = false

  inline_policy_json = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:StartInstances",
          "ec2:StopInstances"
        ],
        Resource = "arn:aws:ec2:ap-northeast-2:236450698266:instance/${local.backend_instance_id},${local.frontend_instance_id},${local.db_instance_id}"
      },
      {
        Effect = "Allow"
        Action = [
        "secretsmanager:GetSecretValue"
      ]
      Resource = [
        "arn:aws:secretsmanager:ap-northeast-2:236450698266:secret:pumati-prod-discord-webhook-.env*"
      ]
      }
    ]
  })
}

#---------------------------------------------------------------------------------------------------------------------
# 3. Lambda Scheduler
#---------------------------------------------------------------------------------------------------------------------
module "ec2_scheduler_lambda" {
  source = "../../common/module/lambda_function"

  project_name  = local.project_name
  environment   = local.environment
  tags          = local.common_tags

  service_name  = "ec2-scheduler"

  lambda_source_file = "${path.module}/lambda_scripts/ec2_scheduler.py"
  publish            = true

  lambda_role_arn = module.lambda_scheduler_role.role_arn
  handler         = "ec2_scheduler.lambda_handler"
  runtime         = "python3.12"
  timeout         = 30

  environment_variables = {
    INSTANCE_IDS        = "${local.backend_instance_id},${local.frontend_instance_id},${local.db_instance_id}"
    DISCORD_WEBHOOK_URL = "pumati-prod-discord-webhook-.env"
  }
}

#---------------------------------------------------------------------------------------------------------------------
# 4. EventBridge Scheduler
#---------------------------------------------------------------------------------------------------------------------
module "start_ec2_schedule" { 
  source = "../../common/module/eventbridge_scheduler"

  project_name         = local.project_name
  environment          = local.environment
  tags                 = local.common_tags

  service_name         = "ec2-start"

  rule_name            = "start-ec2-schedule"
  schedule_expression  = "cron(0 0 * * ? *)"  # UTC 0시 → KST 오전 9시
  description          = "Start EC2 every day at 9AM KST"
  target_id            = "StartEC2"

  lambda_arn           = module.ec2_scheduler_lambda.lambda_arn
  lambda_function_name = module.ec2_scheduler_lambda.lambda_function_name
  input_json           = jsonencode({ action = "start" })
}

module "stop_ec2_schedule" {
  source = "../../common/module/eventbridge_scheduler"

  project_name         = local.project_name
  environment          = local.environment
  tags                 = local.common_tags

  service_name         = "ec2-stop"

  rule_name            = "stop-ec2-schedule"
  schedule_expression  = "cron(0 12 * * ? *)"  # UTC 12시 → KST 오후 9시
  description          = "Stop EC2 every day at 9PM KST"
  target_id            = "StopEC2"

  lambda_arn           = module.ec2_scheduler_lambda.lambda_arn
  lambda_function_name = module.ec2_scheduler_lambda.lambda_function_name
  input_json           = jsonencode({ action = "stop" })
}
