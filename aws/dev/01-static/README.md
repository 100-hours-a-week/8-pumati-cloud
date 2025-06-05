<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.97.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_route53_record.acm_validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_s3_bucket.db_backup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.db_backup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_public_access_block.db_backup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.db_backup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.db_backup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_secretsmanager_secret.discord_webhooks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.discord_webhooks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_route53_zone.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |
| [terraform_remote_state.common](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_discord_webhook_url"></a> [discord\_webhook\_url](#input\_discord\_webhook\_url) | jacky의 디스코드 웹훅 URL | `string` | n/a | yes |
| <a name="input_discord_webhook_url_all"></a> [discord\_webhook\_url\_all](#input\_discord\_webhook\_url\_all) | 팀 전체용 디스코드 웹훅 URL | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_acm_certificate_arn"></a> [acm\_certificate\_arn](#output\_acm\_certificate\_arn) | ACM 인증서 ARN |
| <a name="output_acm_certificate_domain_name"></a> [acm\_certificate\_domain\_name](#output\_acm\_certificate\_domain\_name) | ACM 인증서 도메인 이름 |
| <a name="output_db_backup_bucket_arn"></a> [db\_backup\_bucket\_arn](#output\_db\_backup\_bucket\_arn) | DB 백업용 S3 버킷 ARN |
| <a name="output_db_backup_bucket_name"></a> [db\_backup\_bucket\_name](#output\_db\_backup\_bucket\_name) | DB 백업용 S3 버킷 이름 |
| <a name="output_discord_webhook_url"></a> [discord\_webhook\_url](#output\_discord\_webhook\_url) | jacky용 디스코드 웹훅 URL |
| <a name="output_discord_webhook_url_all"></a> [discord\_webhook\_url\_all](#output\_discord\_webhook\_url\_all) | 팀 전체용 디스코드 웹훅 URL |
| <a name="output_discord_webhooks_secret_arn"></a> [discord\_webhooks\_secret\_arn](#output\_discord\_webhooks\_secret\_arn) | 디스코드 웹훅 시크릿 ARN |
<!-- END_TF_DOCS -->