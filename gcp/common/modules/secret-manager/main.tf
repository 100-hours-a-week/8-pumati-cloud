# modules/secret-manager/main.tf - Secret Manager 모듈 정의

# Secret Manager 시크릿 생성
resource "google_secret_manager_secret" "secret" {
  project   = var.project_id
  secret_id = var.secret_id
  
  # 복제 설정
  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
  
  # 라벨 설정
  labels = var.labels
}

# 시크릿 값(버전) 생성
resource "google_secret_manager_secret_version" "secret_version" {
  secret      = google_secret_manager_secret.secret.id
  secret_data = var.secret_value
}

# # 접근 권한 설정 (선택적)
# resource "google_secret_manager_secret_iam_binding" "secret_access" {
#   count      = length(var.secret_accessors) > 0 ? 1 : 0
  
#   project   = var.project_id
#   secret_id = google_secret_manager_secret.secret.secret_id
#   role      = "roles/secretmanager.secretAccessor"
#   members   = var.secret_accessors
  
#   depends_on = [
#     google_secret_manager_secret.secret
#   ]
# }