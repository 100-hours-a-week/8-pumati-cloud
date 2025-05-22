메인모듈 적용 순서 정리

00-static
01-common 
02-network	VPC, Subnet, IGW 등 네트워크 구성
03-security	보안 그룹, IAM 등 보안 설정
04-compute	EC2 인스턴스, EIP 등 생성
05-dns	도메인(A레코드) <-> EIP 연결

