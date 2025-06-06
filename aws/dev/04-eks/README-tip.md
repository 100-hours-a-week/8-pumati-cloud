# 🚀 EKS 클러스터 Apply 확인 가이드

## 📋 1. Terraform Apply 성공 여부 확인

### **Apply 실행**
```bash
cd aws/dev/04-eks
terraform plan    # 먼저 계획 확인
terraform apply   # 실행 (15-20분 소요)
```

### **Apply 성공 확인**
```bash
# 출력 메시지에서 다음 내용 확인:
# Apply complete! Resources: XX added, 0 changed, 0 destroyed.

# 생성된 리소스 확인
terraform output
```

## 🔍 2. AWS 콘솔에서 EKS 클러스터 확인

### **EKS 클러스터 상태**
1. **AWS Console** → **EKS** → **Clusters**
2. `pumati-dev-eks-cluster` 확인
3. **Status**: `ACTIVE` 여야 함
4. **Endpoint**: API 서버 엔드포인트 확인

### **노드 그룹 상태**
1. **클러스터 상세** → **Compute** 탭
2. `pumati-dev-system-nodes` 확인
3. **Status**: `ACTIVE` 여야 함
4. **Desired/Running**: `2` 여야 함

### **Add-ons 상태**
1. **클러스터 상세** → **Add-ons** 탭
2. 다음 4개 add-ons가 `ACTIVE` 상태여야 함:
   - `vpc-cni`
   - `coredns`
   - `kube-proxy`
   - `aws-ebs-csi-driver`

## 🛠️ 3. kubectl로 클러스터 접근 확인

### **kubeconfig 설정**
```bash
# 반드시 EKS 만든 계정으로 먼저 들억가ㅣ
aws-use-ktb8team-jacky

# AWS CLI로 kubeconfig 업데이트
aws eks update-kubeconfig \
  --region ap-northeast-2 \
  --name pumati-dev-eks-cluster

# 클러스터 접근 확인
kubectl cluster-info
```

### **노드 상태 확인**
```bash
# 노드 목록 확인
kubectl get nodes

# 노드 상세 정보 확인
kubectl get nodes -o wide

# 예상 결과:
# NAME                                               STATUS   ROLES    AGE   VERSION
# ip-10-0-x-x.ap-northeast-2.compute.internal      Ready    <none>   5m    v1.28.x
# ip-10-0-x-x.ap-northeast-2.compute.internal      Ready    <none>   5m    v1.28.x
```

### **시스템 Pod 상태 확인**
```bash
# kube-system 네임스페이스의 모든 Pod 확인
kubectl get pods -n kube-system

# 다음 Pod들이 Running 상태여야 함:
# - coredns-xxx (2개)
# - aws-node-xxx (노드 수만큼)
# - kube-proxy-xxx (노드 수만큼)
# - ebs-csi-controller-xxx (2개)
# - ebs-csi-node-xxx (노드 수만큼)
```

## 🏷️ 4. 노드 라벨 및 Taint 확인

### **시스템 노드 라벨 확인**
```bash
# 노드 라벨 확인
kubectl get nodes --show-labels

# 다음 라벨들이 있어야 함:
# node-type=system
# capacity-type=on-demand
# role=system-component
```

### **시스템 노드 Taint 확인**
```bash
# 노드 Taint 확인
kubectl describe nodes | grep -A5 Taints

# 다음 Taint가 있어야 함:
# node-type=system:NoSchedule
```

## 🌐 5. 네트워킹 및 보안 그룹 확인

### **보안 그룹 확인**
```bash
# AWS CLI로 보안 그룹 확인
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=*eks*" \
  --query 'SecurityGroups[*].[GroupName,GroupId]' \
  --output table
```

### **VPC CNI 설정 확인**
```bash
# VPC CNI 설정 확인
kubectl describe daemonset aws-node -n kube-system

# ENICONFIG 확인 (필요시)
kubectl get eniconfigs
```

## 🔧 6. 문제 해결

### **노드가 Ready 상태가 아닐 때**
```bash
# 노드 상세 정보 확인
kubectl describe node <node-name>

# 시스템 로그 확인
kubectl logs -n kube-system -l k8s-app=aws-node
```

### **Pod들이 Pending 상태일 때**
```bash
# Pod 상세 정보 확인
kubectl describe pod <pod-name> -n kube-system

# 이벤트 확인
kubectl get events -n kube-system --sort-by='.lastTimestamp'
```

### **클러스터 접근이 안 될 때**
```bash
# AWS 인증 정보 확인
aws sts get-caller-identity

# kubeconfig 파일 확인
cat ~/.kube/config

# 클러스터 엔드포인트 접근 확인
curl -k <cluster-endpoint>/version
```

## ✅ 7. 성공 확인 체크리스트

- [ ] Terraform apply 성공 (모든 리소스 생성됨)
- [ ] EKS 클러스터 상태: `ACTIVE`
- [ ] 노드 그룹 상태: `ACTIVE`, 2개 노드 Running
- [ ] 4개 Add-ons 모두 `ACTIVE` 상태
- [ ] `kubectl get nodes`로 2개 노드 확인
- [ ] 모든 시스템 Pod들이 `Running` 상태
- [ ] 시스템 노드에 올바른 라벨과 Taint 설정
- [ ] 보안 그룹들이 올바르게 생성됨

## 🚨 8. 주의사항

### **비용 관리**
- **EKS 클러스터**: 시간당 $0.10 (약 월 $72)
- **EC2 인스턴스**: t3.small 2개 (약 월 $30)
- **총 예상 비용**: 약 월 $100

### **리소스 정리**
```bash
# 테스트 완료 후 리소스 삭제
terraform destroy

# 정리 전 확인사항:
# - ALB나 기타 Kubernetes 리소스가 있다면 먼저 삭제
# - PVC(영구 볼륨)가 있다면 수동 삭제 필요
```

### **다음 단계**
- 성공 확인 후 → **05-workload** 디렉토리에서 Karpenter 설치
- Karpenter 설치 후 → 애플리케이션 배포
- 로드밸런서 및 Ingress 설정
