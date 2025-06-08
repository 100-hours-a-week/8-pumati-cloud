# S3 버킷 관련 출력
output "db_backup_bucket_arn" {
  description = "DB 백업용 S3 버킷 ARN"
  value       = aws_s3_bucket.db_backup.arn
}

output "db_backup_bucket_name" {
  description = "DB 백업용 S3 버킷 이름"
  value       = aws_s3_bucket.db_backup.bucket
}

# 디스코드 웹훅 시크릿 관련 출력
output "discord_webhooks_secret_arn" {
  description = "디스코드 웹훅 시크릿 ARN"
  value       = aws_secretsmanager_secret.discord_webhooks.arn
}

output "discord_webhook_url" {
  description = "jacky용 디스코드 웹훅 URL"
  value       = jsondecode(aws_secretsmanager_secret_version.discord_webhooks.secret_string).discord_webhook_url
  sensitive   = true
}

output "discord_webhook_url_all" {
  description = "팀 전체용 디스코드 웹훅 URL"
  value       = jsondecode(aws_secretsmanager_secret_version.discord_webhooks.secret_string).discord_webhook_url_all
  sensitive   = true
}

# ACM 인증서 관련 출력
output "acm_certificate_arn" {
  description = "ACM 인증서 ARN"
  value       = aws_acm_certificate_validation.this.certificate_arn
}

output "acm_certificate_domain_name" {
  description = "ACM 인증서 도메인 이름"
  value       = aws_acm_certificate.this.domain_name
}

#==============================================================================
# Jenkins EBS 볼륨 관련 출력
#==============================================================================

# Jenkins 마스터 EBS 볼륨 정보
output "jenkins_master_ebs_volume_id" {
  description = "Jenkins 마스터용 EBS 볼륨 ID"
  value       = aws_ebs_volume.jenkins_master.id
}

output "jenkins_master_ebs_volume_arn" {
  description = "Jenkins 마스터용 EBS 볼륨 ARN"
  value       = aws_ebs_volume.jenkins_master.arn
}

output "jenkins_master_ebs_availability_zone" {
  description = "Jenkins 마스터 EBS 볼륨이 위치한 가용영역"
  value       = aws_ebs_volume.jenkins_master.availability_zone
}

output "jenkins_master_ebs_size" {
  description = "Jenkins 마스터 EBS 볼륨 크기 (GB)"
  value       = aws_ebs_volume.jenkins_master.size
}

output "jenkins_master_ebs_type" {
  description = "Jenkins 마스터 EBS 볼륨 타입"
  value       = aws_ebs_volume.jenkins_master.type
}

output "jenkins_master_ebs_encrypted" {
  description = "Jenkins 마스터 EBS 볼륨 암호화 여부"
  value       = aws_ebs_volume.jenkins_master.encrypted
}

# Jenkins 06-ci에서 사용할 종합 정보
output "jenkins_ebs_info" {
  description = "Jenkins 구성에 필요한 EBS 볼륨 정보"
  value = {
    volume_id         = aws_ebs_volume.jenkins_master.id
    availability_zone = aws_ebs_volume.jenkins_master.availability_zone
    size             = aws_ebs_volume.jenkins_master.size
    type             = aws_ebs_volume.jenkins_master.type
    encrypted        = aws_ebs_volume.jenkins_master.encrypted
    iops             = aws_ebs_volume.jenkins_master.iops
    throughput       = aws_ebs_volume.jenkins_master.throughput
  }
}

# DLM 정책 정보
output "jenkins_dlm_policy_arn" {
  description = "Jenkins EBS 볼륨 자동 백업 DLM 정책 ARN"
  value       = aws_dlm_lifecycle_policy.jenkins_backup.arn
}

# Kubernetes에서 사용할 볼륨 선택기 정보
output "jenkins_volume_selector" {
  description = "Kubernetes PV에서 사용할 볼륨 선택기 정보"
  value = {
    volume_id = aws_ebs_volume.jenkins_master.id
    zone      = aws_ebs_volume.jenkins_master.availability_zone
    tags = {
      "kubernetes.io/created-for/pv/name" = "jenkins-master-pv"
      VolumeType = "jenkins-master"
    }
  }
}

#==============================================================================
# ECR (Elastic Container Registry) 관련 출력
#==============================================================================

# 백엔드 ECR 정보
output "backend_ecr_repository_url" {
  description = "백엔드 ECR 저장소 URL"
  value       = aws_ecr_repository.backend.repository_url
}

output "backend_ecr_repository_arn" {
  description = "백엔드 ECR 저장소 ARN"
  value       = aws_ecr_repository.backend.arn
}

output "backend_ecr_repository_name" {
  description = "백엔드 ECR 저장소 이름"
  value       = aws_ecr_repository.backend.name
}

# 프론트엔드 ECR 정보  
output "frontend_ecr_repository_url" {
  description = "프론트엔드 ECR 저장소 URL"
  value       = aws_ecr_repository.frontend.repository_url
}

output "frontend_ecr_repository_arn" {
  description = "프론트엔드 ECR 저장소 ARN"
  value       = aws_ecr_repository.frontend.arn
}

output "frontend_ecr_repository_name" {
  description = "프론트엔드 ECR 저장소 이름"
  value       = aws_ecr_repository.frontend.name
}

# Jenkins에서 사용할 ECR 종합 정보
output "ecr_repositories" {
  description = "Jenkins CI/CD에서 사용할 ECR 저장소 정보"
  value = {
    backend = {
      name = aws_ecr_repository.backend.name
      url  = aws_ecr_repository.backend.repository_url
      arn  = aws_ecr_repository.backend.arn
    }
    frontend = {
      name = aws_ecr_repository.frontend.name
      url  = aws_ecr_repository.frontend.repository_url
      arn  = aws_ecr_repository.frontend.arn
    }
  }
}

# ECR 로그인을 위한 AWS 계정 정보
output "aws_account_id" {
  description = "ECR 로그인에 필요한 AWS 계정 ID"
  value       = data.aws_caller_identity.current.account_id
}

# ECR 로그인 명령어 (Jenkins에서 참고용)
output "ecr_login_command" {
  description = "ECR 로그인 명령어 (Jenkins에서 사용)"
  value       = "aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin ${aws_ecr_repository.backend.repository_url}"
}

#==============================================================================
# ArgoCD EBS 볼륨 관련 출력 (Jenkins 패턴과 동일하게)
#==============================================================================

# ArgoCD 서버 EBS 볼륨 정보
output "argocd_server_ebs_volume_id" {
  description = "ArgoCD 서버용 EBS 볼륨 ID"
  value       = aws_ebs_volume.argocd_server.id
}

output "argocd_server_ebs_volume_arn" {
  description = "ArgoCD 서버용 EBS 볼륨 ARN"
  value       = aws_ebs_volume.argocd_server.arn
}

output "argocd_server_ebs_availability_zone" {
  description = "ArgoCD 서버 EBS 볼륨이 위치한 가용영역"
  value       = aws_ebs_volume.argocd_server.availability_zone
}

output "argocd_server_ebs_size" {
  description = "ArgoCD 서버 EBS 볼륨 크기 (GB)"
  value       = aws_ebs_volume.argocd_server.size
}

output "argocd_server_ebs_type" {
  description = "ArgoCD 서버 EBS 볼륨 타입"
  value       = aws_ebs_volume.argocd_server.type
}

output "argocd_server_ebs_encrypted" {
  description = "ArgoCD 서버 EBS 볼륨 암호화 여부"
  value       = aws_ebs_volume.argocd_server.encrypted
}

# ArgoCD 07에서 사용할 종합 정보
output "argocd_ebs_info" {
  description = "ArgoCD 구성에 필요한 EBS 볼륨 정보"
  value = {
    volume_id         = aws_ebs_volume.argocd_server.id
    availability_zone = aws_ebs_volume.argocd_server.availability_zone
    size             = aws_ebs_volume.argocd_server.size
    type             = aws_ebs_volume.argocd_server.type
    encrypted        = aws_ebs_volume.argocd_server.encrypted
    iops             = aws_ebs_volume.argocd_server.iops
    throughput       = aws_ebs_volume.argocd_server.throughput
  }
}

# Kubernetes에서 사용할 볼륨 선택기 정보
output "argocd_volume_selector" {
  description = "Kubernetes PV에서 사용할 볼륨 선택기 정보"
  value = {
    volume_id = aws_ebs_volume.argocd_server.id
    zone      = aws_ebs_volume.argocd_server.availability_zone
    tags = {
      "kubernetes.io/created-for/pv/name" = "argocd-server-pv"
      VolumeType = "argocd-server"
    }
  }
}
