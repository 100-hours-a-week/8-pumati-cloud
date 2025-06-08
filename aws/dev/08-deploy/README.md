# 08-deploy: 애플리케이션 배포

이 디렉토리는 **ArgoCD를 통한 애플리케이션 배포**를 담당합니다.

## 📋 **전제 조건**

- **07-argocd**가 먼저 성공적으로 배포되어 ArgoCD 서버가 실행 중이어야 합니다
- ArgoCD 서버에 외부에서 접근 가능해야 합니다 (`argocd.domain.com`)

## 🚀 **배포 순서**

### 1. terraform.tfvars 파일 설정

```bash
# 예제 파일을 복사
cp terraform.tfvars.example terraform.tfvars

# terraform.tfvars 파일 편집
# ArgoCD admin 비밀번호를 07-argocd에서 설정한 것과 동일하게 설정
vim terraform.tfvars
```

### 2. Terraform 초기화 및 배포

```bash
# Terraform 초기화
terraform init

# 배포 계획 확인
terraform plan

# 애플리케이션 배포
terraform apply
```

## 📦 **배포되는 애플리케이션들**

### 🔧 **백엔드 애플리케이션**
- **이름**: `pumati-backend`
- **소스**: `aws/dev/gitops/helm/backend`
- **네임스페이스**: `pumati`
- **자동 동기화**: 활성화

### 🎨 **프론트엔드 애플리케이션**
- **이름**: `pumati-frontend`
- **소스**: `aws/dev/gitops/helm/frontend`
- **네임스페이스**: `pumati`
- **자동 동기화**: 활성화

## 🔍 **배포 확인**

### ArgoCD UI에서 확인
```bash
# ArgoCD 서버 URL 확인
terraform output argocd_server_url

# 브라우저에서 ArgoCD에 접속하여 애플리케이션 상태 확인
```

### Kubernetes 명령어로 확인
```bash
# 네임스페이스 확인
kubectl get namespaces

# Pumati 네임스페이스의 리소스 확인
kubectl get all -n pumati

# ArgoCD 애플리케이션 확인
kubectl get applications -n argocd
```

## 🐛 **문제 해결**

### ArgoCD Provider 연결 에러
```bash
# ArgoCD 서버 상태 확인
kubectl get pods -n argocd

# ArgoCD 서비스 확인
kubectl get svc -n argocd

# ArgoCD Ingress 확인
kubectl get ingress -n argocd
```

### 애플리케이션 동기화 실패
1. ArgoCD UI에서 애플리케이션 상태 확인
2. Git 저장소의 Helm Chart 구성 확인
3. 네임스페이스 및 권한 확인

## 🔄 **GitOps 워크플로우**

1. **코드 변경**: Git 저장소의 Helm Chart 수정
2. **자동 감지**: ArgoCD가 변경사항을 자동으로 감지
3. **자동 배포**: 설정된 동기화 정책에 따라 자동 배포
4. **상태 확인**: ArgoCD UI에서 배포 상태 모니터링

## 📚 **관련 문서**

- [ArgoCD 공식 문서](https://argo-cd.readthedocs.io/)
- [Helm Chart 구성 가이드](../gitops/helm/)
- [07-argocd README](../07-argocd/README.md) 