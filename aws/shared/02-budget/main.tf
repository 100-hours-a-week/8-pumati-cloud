#---------------------------------------------------------------------------------------------------------------------
# 1. Discord Secrets Manager
#---------------------------------------------------------------------------------------------------------------------
module "discord_budget_alert_secret" {
  source = "../../common/module/secretsmanager"

  project_name  = local.project_name
  environment   = local.environment
  tags          = local.common_tags

  service_name  = "discord-webhook-budget-alert-limit"
  env_file_path = "../../common/envs/discord/budget_alert/.env"
  kms_key_id    = "arn:aws:kms:ap-northeast-2:236450698266:key/93a8affe-a6f3-4f22-bdcc-dfafac23e42d"
}


# ----------------------------------------------------------------------------------------------------------------------
# 1. Lambda Scheduler Role
# ----------------------------------------------------------------------------------------------------------------------
module "lambda_budget_alert_iam" {
  source                   = "../../common/module/iam_role"
  project_name             = local.project_name
  environment              = local.environment
  service_name             = "budget-alert"
  assume_role_service      = "lambda.amazonaws.com"
  instance_profile_enabled = false
  tags                     = local.common_tags

  enable_inline_policy  = true
  enable_managed_policy = true

  inline_policy_json = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow",
        Action = [
          "sns:Publish"
        ],
        Resource = module.budget_alert_sns.topic_arn
      },
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue"
        ],
        Resource = module.discord_budget_alert_secret.secret_arn
      }
    ]
  })
}



# ----------------------------------------------------------------------------------------------------------------------
# 2. Lambda 함수 생성
# ----------------------------------------------------------------------------------------------------------------------
module "budget_alert_lambda" {
  source = "../../common/module/lambda_function"

  project_name  = local.project_name
  environment   = local.environment
  service_name  = "budget-alert"
  tags          = local.common_tags

  lambda_source_file = "${path.module}/lambda_scripts/budget_alert.py"
  publish            = true

  lambda_role_arn = module.lambda_budget_alert_iam.role_arn
  handler         = "budget_alert.lambda_handler"
  runtime         = "python3.12"
  timeout         = 10

  environment_variables = {
    DISCORD_SECRET_NAME = module.discord_budget_alert_secret.secret_name
  }
}

# ----------------------------------------------------------------------------------------------------------------------
# 3. CloudWatch Log Group for Lambda
# ----------------------------------------------------------------------------------------------------------------------
module "budget_alert_logs" {
  source = "../../common/module/cloudwatch"

  project_name     = local.project_name
  environment      = local.environment
  tags             = local.common_tags
  
  service_name     = "budget-alert"
  log_group_name   = "/aws/lambda/${module.budget_alert_lambda.lambda_function_name}"
  retention_in_days = 7
}

# ----------------------------------------------------------------------------------------------------------------------
# 4. SNS 생성
# ----------------------------------------------------------------------------------------------------------------------
module "budget_alert_sns" {
  source = "../../common/module/sns"

  project_name          = local.project_name
  environment           = local.environment
  service_name          = "budget-alert"
  tags                  = local.common_tags

  lambda_function_name  = module.budget_alert_lambda.lambda_function_name
  lambda_function_arn   = module.budget_alert_lambda.lambda_arn
}

# ----------------------------------------------------------------------------------------------------------------------
# 5. Budget 생성
# ----------------------------------------------------------------------------------------------------------------------
module "budget" {
  source           = "../../common/module/budget"
  project_name     = local.project_name
  environment      = local.environment
  tags             = local.common_tags

  service_name     = "budget"
  budget_limit     = "450"  
  start_time       = "2025-07-01_00:00"
  end_time         = "2025-07-31_23:59"
  alert_email      = ["qkrdufdl3580@gmail.com"]
  sns_topic_arn    = module.budget_alert_sns.topic_arn

  notification_settings = [
    {
      threshold          = 50
      threshold_type     = "PERCENTAGE"
      notification_type  = "ACTUAL"
      enable_sns         = true
    },
    {
      threshold          = 80
      threshold_type     = "PERCENTAGE"
      notification_type  = "ACTUAL"
      enable_sns         = true
    },
    {
      threshold          = 90
      threshold_type     = "PERCENTAGE"
      notification_type  = "ACTUAL"
      enable_sns         = true
    },
    { 
      threshold          = 100
      threshold_type     = "PERCENTAGE"
      notification_type  = "FORECASTED"
      enable_sns         = true
    }
  ]
}