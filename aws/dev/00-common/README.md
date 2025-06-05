<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

No providers.

## Modules

No modules.

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_common_tags"></a> [common\_tags](#input\_common\_tags) | 모든 리소스에 적용될 공통 태그 | `map(string)` | n/a | yes |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | 서비스 도메인 이름 | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | 환경 (dev, staging, prod, test, shared) | `string` | n/a | yes |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | 프로젝트 이름 | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS 리전 | `string` | n/a | yes |
| <a name="input_tfstate_bucket"></a> [tfstate\_bucket](#input\_tfstate\_bucket) | 테라폼 상태를 저장할 S3 버킷 이름 | `string` | n/a | yes |
| <a name="input_tfstate_region"></a> [tfstate\_region](#input\_tfstate\_region) | 테라폼 상태 버킷이 위치한 리전 | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_common_tags"></a> [common\_tags](#output\_common\_tags) | 모든 리소스에 적용될 공통 태그 |
| <a name="output_domain_name"></a> [domain\_name](#output\_domain\_name) | 서비스 도메인 이름 |
| <a name="output_environment"></a> [environment](#output\_environment) | 환경 (dev, staging, prod) |
| <a name="output_project_name"></a> [project\_name](#output\_project\_name) | 프로젝트 이름 |
| <a name="output_region"></a> [region](#output\_region) | AWS 리전 |
| <a name="output_tfstate_bucket"></a> [tfstate\_bucket](#output\_tfstate\_bucket) | 테라폼 상태를 저장할 S3 버킷 이름 |
| <a name="output_tfstate_region"></a> [tfstate\_region](#output\_tfstate\_region) | 테라폼 상태 버킷이 위치한 리전 |
<!-- END_TF_DOCS -->