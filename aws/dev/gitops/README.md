# GitOps - App of Apps 배포 구성

이 디렉토리는 ArgoCD의 App of Apps 패턴을 사용하여 프론트엔드 애플리케이션을 배포하는 구성을 포함합니다.

## 📁 디렉토리 구조

```
aws/dev/gitops/
├── app-of-apps.yaml          # 메인 App of Apps 애플리케이션
├── applications/             # 개별 애플리케이션 정의
│   └── frontend-app.yaml     # 프론트엔드 애플리케이션 정의
├── helm/                     # Helm 차트들
│   └── frontend/             # 프론트엔드 Helm 차트
│       ├── Chart.yaml        # 차트 메타데이터
│       ├── values.yaml       # 기본 설정값
│       ├── values-dev.yaml   # 개발 환경 설정값
│       └── templates/        # Kubernetes 템플릿
│           ├── _helpers.tpl  # 헬퍼 함수
│           ├── deployment.yaml
│           ├── service.yaml
│           └── ingress.yaml
└── README.md                 # 이 파일
```

## 🚀 배포 방법

### 1. 사전 준비사항

- ArgoCD가 클러스터에 설치되어 있어야 합니다
- Git 저장소 URL을 실제 저장소로 변경해야 합니다
- 이미지 저장소 정보를 실제 정보로 업데이트해야 합니다

### 2. 설정 수정

#### Git 저장소 URL 변경
다음 파일들에서 `https://github.com/your-repo/8-pumati-cloud.git`을 실제 저장소 URL로 변경:
- `app-of-apps.yaml`
- `applications/frontend-app.yaml`

#### 이미지 저장소 변경
`helm/frontend/values.yaml`과 `helm/frontend/values-dev.yaml`에서:
```yaml
image:
  repository: your-registry/frontend  # 실제 이미지 저장소로 변경
```

### 3. App of Apps 배포

```bash
# ArgoCD CLI로 배포
kubectl apply -f app-of-apps.yaml

# 또는 ArgoCD UI에서 애플리케이션 생성
```

### 4. 배포 상태 확인

```bash
# ArgoCD 애플리케이션 상태 확인
kubectl get applications -n argocd

# 프론트엔드 파드 상태 확인
kubectl get pods -n frontend-dev
```

## 🔧 환경별 설정

### 개발 환경 (values-dev.yaml)
- 디버그 모드 활성화
- 낮은 리소스 제한
- 개발용 도메인 설정
- 자동 이미지 풀 정책

### 운영 환경 추가 시
1. `values-prod.yaml` 파일 생성
2. `applications/frontend-prod-app.yaml` 애플리케이션 정의 추가
3. App of Apps에 운영 환경 애플리케이션 추가

## 📝 주요 특징

### App of Apps 패턴의 장점
- **중앙 집중식 관리**: 하나의 애플리케이션으로 여러 애플리케이션 관리
- **일관된 배포**: 모든 환경에서 동일한 배포 프로세스
- **계층적 구조**: 애플리케이션 간의 의존성 관리 용이
- **자동 동기화**: GitOps 방식으로 자동 배포

### 보안 및 모니터링
- 비루트 사용자로 컨테이너 실행
- 리소스 제한 설정
- 헬스체크 및 준비 상태 확인
- 자동 재시작 정책

## 🛠️ 문제 해결

### 일반적인 문제들

1. **이미지 풀 실패**
   - 이미지 저장소 URL 확인
   - 인증 정보 확인

2. **인그레스 접근 불가**
   - 인그레스 컨트롤러 설치 확인
   - DNS 설정 확인

3. **동기화 실패**
   - Git 저장소 접근 권한 확인
   - ArgoCD 설정 확인

### 로그 확인
```bash
# ArgoCD 애플리케이션 로그
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# 프론트엔드 애플리케이션 로그
kubectl logs -n frontend-dev -l app.kubernetes.io/name=frontend
```

## 📚 추가 정보

- [ArgoCD 공식 문서](https://argo-cd.readthedocs.io/)
- [Helm 차트 개발 가이드](https://helm.sh/docs/chart_template_guide/)
- [Kubernetes 배포 전략](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/) 