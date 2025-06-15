# prod VPC에서 shared VPC로의 피어링 라우트 설정
# shared VPC에서 생성된 피어링 연결을 참조하여 라우트 추가

# shared 환경의 피어링 정보를 가져오기
data "terraform_remote_state" "shared_network" {
  backend = "s3"
  config = {
    bucket = "s3-pumati-tfstate"
    key    = "aws/shared/network/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# prod VPC의 퍼블릭 라우팅 테이블에 shared VPC로의 라우트 추가
resource "aws_route" "prod_to_shared_public" {
  route_table_id            = module.vpc.public_route_table_id
  destination_cidr_block    = data.terraform_remote_state.shared_network.outputs.shared_vpc_cidr
  vpc_peering_connection_id = data.terraform_remote_state.shared_network.outputs.vpc_peering_connection_id
}

# 참고: 보안 그룹 규칙은 별도의 security 모듈에서 관리됩니다.
# 필요시 aws/prod/03-security/main.tf에서 management_sg 모듈에 
# shared VPC CIDR 허용 규칙을 추가하세요. 