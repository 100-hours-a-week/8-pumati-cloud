# Jenkins 에이전트를 위한 MIG 설정
# MIG 모듈을 사용하여 스팟 인스턴스 생성

# Jenkins 에이전트 MIG 설정
module "jenkins_agent_mig" {
  source = "../../common/modules/mig"
  
  # 프로젝트 설정
  project_id = local.project_id
  region     = local.region
  zones      = ["${local.region}-a", "${local.region}-b", "${local.region}-c"]
  
  # 인스턴스 기본 설정
  instance_name = "jenkins-agent"
  machine_type  = "e2-standard-4"   # 8vCPU, 32GB 메모리
  spot          = true            # 스팟 인스턴스 사용
  
  # 디스크 설정
  source_image_family  = "debian-11"
  source_image_project = "debian-cloud"
  disk_size_gb         = 20
  disk_type            = "pd-balanced"
  
  # GPU 설정 (GPU 필요 없음)
  gpu_type  = ""
  gpu_count = 0
  
  # 네트워크 설정
  network    = "default"
  subnetwork = ""
  
  # 시작 스크립트 - 외부 파일 사용
  startup_script = templatefile("${path.module}/startup-script.sh", {
    jenkins_master_url = "http://${local.jenkins_master_ip}:8080"
    agent_name = "agent-gcp"
    jenkins_admin_secret_id = local.jenkins_admin_secret_id
    format_disk = false  # 디스크 자동 포맷 비활성화 (데이터 보존)
  })
  
  # 메타데이터 설정
  additional_metadata = {
    enable-oslogin = "TRUE"
    jenkins-agent-disk = local.jenkins_agent_disk_self_link
    discord-webhook-url = local.discord_webhook_secret_id
  }
  
  # 서비스 계정 설정
  service_account_email = "terraform@ktb8team-459100.iam.gserviceaccount.com"
  service_account_scopes = ["cloud-platform"]
  
  # MIG 설정
  target_size            = 2
  wait_for_instances     = true
  
  # 헬스 체크 설정
  health_check_port    = 22  # SSH 포트로 상태 체크
  check_interval_sec   = 30
  timeout_sec          = 10
  healthy_threshold    = 1
  unhealthy_threshold  = 5
  initial_delay_sec    = 300 # 5분 초기 대기
  
  # 포트 설정
  http_port  = 80
  https_port = 443
  
  # 업데이트 정책
  update_type                    = "PROACTIVE"
  instance_redistribution_type   = "PROACTIVE"
  minimal_action                 = "REPLACE"
  most_disruptive_allowed_action = "REPLACE"
  max_surge_fixed                = 1
  
  # 태그 및 라벨
  tags = {
    "jenkins-agent" = true,
    "allow-jenkins" = true
  }
  
  labels = merge(local.common_labels, {
    "service"   = "jenkins"
    "component" = "agent"
    "purpose"   = "llm-build"
  })
}

# Jenkins 에이전트 영구 디스크 연결을 위한 방화벽 규칙
resource "google_compute_firewall" "jenkins_agent" {
  name    = "allow-jenkins-master-to-agent"
  network = "default"
  project = local.project_id
  
  allow {
    protocol = "tcp"
    ports    = ["22", "50000"]
  }
  
  # Jenkins 마스터 IP에서만 접근 허용
  source_tags = ["jenkins", "master"]
  target_tags = ["jenkins-agent"]
  
  description = "Jenkins 마스터가 에이전트에 연결하기 위한 방화벽 규칙"
}
