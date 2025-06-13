#!/bin/bash
set -o xtrace

# EKS 워커 노드 부트스트랩 스크립트
# Karpenter가 생성하는 EC2 인스턴스가 EKS 클러스터에 자동으로 조인하도록 설정

# EKS 부트스트랩 스크립트 실행
# 클러스터 이름, API 서버 엔드포인트, CA 인증서를 사용하여 노드를 클러스터에 등록
/etc/eks/bootstrap.sh ${cluster_name} \
  --apiserver-endpoint ${cluster_endpoint} \
  --b64-cluster-ca ${cluster_ca} \
  --dns-cluster-ip 172.20.0.10 \
  --container-runtime containerd

# 추가 설정들
echo "net.ipv4.conf.all.route_localnet = 1" >> /etc/sysctl.conf
sysctl -p /etc/sysctl.conf

# 로그 설정
echo "Bootstrap completed successfully" > /var/log/bootstrap.log
