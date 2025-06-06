# 05-workloads 테스트 방법 가이드

이 문서는 05-workloads 모듈 배포 후 각 컴포넌트가 정상적으로 동작하는지 확인하는 방법을 제공합니다.

## 🚀 배포 후 기본 확인

### 1. 모든 Pod 상태 확인
```bash
# 모든 워크로드 컴포넌트 상태 한 번에 확인
kubectl get pods -A | grep -E "(karpenter|aws-load-balancer|external-dns|metrics-server)"

# 예상 결과:
# karpenter       karpenter-controller-xxx    1/1   Running
# kube-system     aws-load-balancer-controller-xxx  1/1   Running  
# kube-system     external-dns-xxx                  1/1   Running
# kube-system     metrics-server-xxx                1/1   Running
```

### 2. 클러스터 전체 상태 확인
```bash
# 노드 상태 확인
kubectl get nodes -o wide

# 모든 네임스페이스의 Pod 상태
kubectl get pods -A

# 클러스터 정보 확인
kubectl cluster-info
```

## 🏗️ Karpenter 테스트

### 1. Karpenter Controller 상태 확인
```bash
# Karpenter 네임스페이스의 Pod 확인
kubectl get pods -n karpenter

# Karpenter 로그 확인
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=100

# NodePool과 EC2NodeClass 확인
kubectl get nodepool -A
kubectl get ec2nodeclass -A
```

### 2. 노드 자동 스케일링 테스트
```bash
# 테스트용 Pod 생성 (리소스 요청이 큰 Pod)
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dev-karpenter
  namespace: default
spec:
  replicas: 5
  selector:
    matchLabels:
      app: dev-karpenter
  template:
    metadata:
      labels:
        app: dev-karpenter
    spec:
      containers:
      - name: pause
        image: k8s.gcr.io/pause:3.8
        resources:
          requests:
            cpu: "1000m"      # 1 CPU 요청
            memory: "1Gi"     # 1GB 메모리 요청
      tolerations:
      - key: "spot-instance"
        operator: "Equal"
        value: "true"
        effect: "NoSchedule"
EOF

# 노드 생성 확인 (2-3분 소요)
watch kubectl get nodes

# Pod 스케줄링 확인
kubectl get pods -o wide

# 테스트 완료 후 정리
kubectl delete deployment dev-karpenter
```

### 3. 노드 축소 테스트
```bash
# 테스트 Pod 삭제 후 노드 자동 제거 확인 (약 10초 대기)
watch kubectl get nodes
```

## 🔄 AWS Load Balancer Controller 테스트

### 1. Controller 상태 확인
```bash
# Controller Pod 상태
kubectl get pods -n kube-system | grep aws-load-balancer-controller

# Controller 로그 확인
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=100

# Webhook 상태 확인
kubectl get validatingwebhookconfiguration | grep aws-load-balancer-webhook
```

### 2. 테스트 애플리케이션 + ALB 생성
```bash
# 테스트 애플리케이션 배포
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dev-app
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: dev-app
  template:
    metadata:
      labels:
        app: dev-app
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
      tolerations:
      - key: "spot-instance"
        operator: "Equal"
        value: "true"
        effect: "NoSchedule"
---
apiVersion: v1
kind: Service
metadata:
  name: dev-app-service
  namespace: default
spec:
  selector:
    app: dev-app
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dev-app-ingress
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    external-dns.alpha.kubernetes.io/hostname: app.dev.tebutebu.com
spec:
  ingressClassName: alb
  rules:
  - host: app.dev.tebutebu.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: dev-app-service
            port:
              number: 80
EOF

# ALB 생성 확인 (3-5분 소요)
kubectl get ingress

# ALB 세부 정보 확인
kubectl describe ingress dev-app-ingress

# AWS 콘솔에서 ALB 생성 확인
echo "AWS 콘솔 > EC2 > Load Balancers에서 ALB 생성 확인"
```

### 3. ALB 접근 테스트
```bash
# ALB 엔드포인트 확인
ALB_ENDPOINT=$(kubectl get ingress dev-app-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "ALB Endpoint: $ALB_ENDPOINT"

# HTTP 요청 테스트
curl -H "Host: app.dev.tebutebu.com" http://$ALB_ENDPOINT

# 또는 도메인으로 직접 접근 (External DNS 동작 후)
# curl http://app.dev.tebutebu.com
```

## 🌐 External DNS 테스트

### 1. External DNS 상태 확인
```bash
# External DNS Pod 상태
kubectl get pods -n kube-system | grep external-dns

# External DNS 로그 확인 (DNS 레코드 생성 확인)
kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns --tail=100

# TXT 레코드로 소유권 확인
nslookup -type=TXT dev.tebutebu.com
```

### 2. DNS 레코드 자동 생성 확인
```bash
# 위에서 생성한 Ingress의 DNS 레코드 확인
nslookup app.dev.tebutebu.com

# Route53에서 레코드 확인
aws route53 list-resource-record-sets --hosted-zone-id YOUR_ZONE_ID | grep app.dev.tebutebu.com

# 또는 AWS 콘솔 > Route53 > Hosted Zones에서 확인
```

### 3. DNS 해상도 테스트
```bash
# 도메인 해상도 확인
dig app.dev.tebutebu.com

# 브라우저 또는 curl로 접근 테스트
curl http://app.dev.tebutebu.com
```

## 📊 Metrics Server 테스트

### 1. Metrics Server 상태 확인
```bash
# Metrics Server Pod 상태
kubectl get pods -n kube-system | grep metrics-server

# API 서비스 상태 확인
kubectl get apiservices | grep metrics

# 결과: v1beta1.metrics.k8s.io의 AVAILABLE이 True여야 함
```

### 2. 리소스 메트릭 확인
```bash
# 노드 리소스 사용량 확인
kubectl top nodes

# 모든 Pod 리소스 사용량 확인
kubectl top pods -A

# 특정 네임스페이스 Pod 확인
kubectl top pods -n kube-system
kubectl top pods -n default
```

### 3. HPA 테스트 (선택사항)
```bash
# 위에서 생성한 dev-app에 HPA 적용
cat <<EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: dev-app-hpa
  namespace: default
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: dev-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
EOF

# HPA 상태 확인
kubectl get hpa

# CPU 부하 테스트 (다른 터미널에서)
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh
# 컨테이너 내부에서: while true; do wget -q -O- http://dev-app-service/; done

# HPA 동작 확인 (몇 분 대기)
watch kubectl get hpa
watch kubectl get pods
```

## 🧹 테스트 정리

### 테스트 리소스 삭제
```bash
# 모든 테스트 리소스 삭제
kubectl delete deployment dev-app
kubectl delete service dev-app-service  
kubectl delete ingress dev-app-ingress
kubectl delete hpa dev-app-hpa

# DNS 레코드는 External DNS가 자동으로 정리함
```

## 🔍 문제 해결

### 일반적인 문제들

#### 1. Karpenter 노드가 생성되지 않을 때
```bash
# Karpenter 로그 확인
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter

# 일반적인 원인:
# - 스팟 인스턴스 가용성 부족
# - IAM 권한 문제
# - 서브넷 설정 문제
```

#### 2. ALB가 생성되지 않을 때
```bash
# AWS Load Balancer Controller 로그 확인
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# 일반적인 원인:
# - IAM 권한 문제
# - 서브넷 태그 누락
# - 보안 그룹 설정 문제
```

#### 3. External DNS가 레코드를 생성하지 않을 때
```bash
# External DNS 로그 확인
kubectl logs -n kube-system -l app.kubernetes.io/name=external-dns

# 일반적인 원인:
# - Route53 권한 문제
# - 도메인 필터 설정 오류 (현재는 tebutebu.com으로 설정됨)
# - Ingress 어노테이션 누락
```

#### 4. Metrics Server가 동작하지 않을 때
```bash
# Metrics Server 로그 확인
kubectl logs -n kube-system -l k8s-app=metrics-server

# 일반적인 원인:
# - kubelet 인증서 문제
# - 네트워크 정책 차단
# - 리소스 부족
```

## ✅ 성공 확인 체크리스트

- [ ] 모든 워크로드 Pod가 Running 상태
- [ ] Karpenter가 노드를 자동 생성/삭제함
- [ ] ALB가 Ingress에 의해 자동 생성됨
- [ ] External DNS가 Route53 레코드를 자동 생성함 (*.tebutebu.com 도메인)
- [ ] Metrics Server가 리소스 사용량을 정상 제공함
- [ ] `kubectl top nodes/pods` 명령어가 정상 동작함

## 📝 다음 단계

테스트가 모두 성공했다면:
1. **06-argocd** 모듈로 GitOps 플랫폼 구축
2. **CI/CD 파이프라인** 구성
3. **모니터링 스택** (Prometheus/Grafana) 설치

---

**📞 문의사항이나 문제가 발생하면 로그를 첨부해서 문의하세요!**
