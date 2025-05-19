# Jenkins 관리자 계정 시크릿 생성
module "jenkins_admin_secret" {
  source = "../../common/modules/secret-manager"
  
  # 프로젝트 설정
  project_id = local.project_id
  region     = local.region
  
  # 시크릿 설정
  # 저기 json 부분 이름 반드시 저렇게 해 줘야 함...그냥 username 이러면 안됨. 
  # 왜냐면 스크립트 안에서 저렇게 찾아서 값 넣으라고 해놨기때문
  secret_id = "jenkins-admin-credentials"
  secret_value = jsonencode({
    jenkins_admin_username = var.jenkins_admin_username
    jenkins_admin_password = var.jenkins_admin_password
  })
  
  labels = local.common_labels
}

#-----------------------------
# Jenkins 마스터 인스턴스 설정
#-----------------------------

# Jenkins 마스터 인스턴스 설정
module "jenkins_master" {
  source = "../../common/modules/compute"

    # 시크릿 모듈 의존성 추가
  depends_on = [module.jenkins_admin_secret]
  
  # 프로젝트 설정
  project_id = local.project_id
  region     = local.region
  zone       = local.zone
  
  # 인스턴스 설정
  instance_name = "jenkins-master"
  machine_type  = "e2-medium"
  spot          = false
  
  # 디스크 설정
  boot_disk_image = "projects/debian-cloud/global/images/family/debian-11"
  boot_disk_size  = 20
  boot_disk_type  = "pd-standard"
  
  # 영구 디스크 연결 (additional_disk_enabled 대신 external_disk 사용)
  external_disk = {
    source      = local.jenkins_master_disk_self_link
    device_name = "jenkins-home"
  }
  
  # 고정 IP 설정
  static_ip_name    = "ip-jenkins-master"
  
  # 네트워크 설정
  network = "default"
  
  # GPU 설정 (Jenkins에는 GPU 불필요)
  gpu_type  = ""
  gpu_count = 0
  
  # 서비스 계정 설정
  service_account_email = "terraform@ktb8team-459100.iam.gserviceaccount.com"
  service_account_scopes = ["cloud-platform"]
  
  # 시작 스크립트 설정
  startup_script = templatefile("${path.module}/startup-script.sh", {
    secret_id = module.jenkins_admin_secret.secret_id
  })
  
  # 메타데이터 설정
  additional_metadata = {
    enable-oslogin = "TRUE"
  }
  
  # 태그 및 라벨 설정
  tags   = ["jenkins", "master"]
  labels = merge(local.common_labels, {
    "service"   = "jenkins"
    "component" = "master"
  })
  
  # 방화벽 규칙 설정
  firewall_rules = {
    name          = "allow-jenkins"
    protocol      = "tcp"
    ports         = ["8080"]
    source_ranges = ["0.0.0.0/0"]
  }


}


