# Artifact Registry 모듈 변수 정의

variable "project_id" {
  description = "GCP 프로젝트 ID"
  type        = string
}

variable "location" {
  description = "Artifact Registry 위치 (리전)"
  type        = string
  default     = "asia-northeast3" # 서울 리전을 기본값으로 설정
}

variable "repository_id" {
  description = "Artifact Registry 저장소 ID"
  type        = string
  default     = "ktb8team-docker-repo"
}

variable "description" {
  description = "Artifact Registry 저장소 설명"
  type        = string
  default     = "Docker 이미지 저장소"
}

variable "format" {
  description = "Artifact Registry 포맷"
  type        = string
  default     = "DOCKER" # Docker 이미지 형식
}

variable "labels" {
  description = "Artifact Registry에 적용할 라벨"
  type        = map(string)
  default     = {
    environment = "production"
    team        = "ktb8team"
  }
}
