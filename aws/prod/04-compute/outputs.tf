# 프론트엔드 인스턴스 출력
output "frontend_instance_id" {
  description = "프론트엔드 인스턴스 ID"
  value       = module.frontend_instance.instance_id
}

output "frontend_public_ip" {
  description = "프론트엔드 인스턴스의 퍼블릭 IP (EIP가 연결된 경우)"
  value       = module.frontend_instance.public_ip
}

# 백엔드 인스턴스 출력
output "backend_instance_id" {
  description = "백엔드 인스턴스 ID"
  value       = module.backend_instance.instance_id
}

output "backend_public_ip" {
  description = "백엔드 인스턴스의 퍼블릭 IP"
  value       = module.backend_instance.public_ip
}

# 젠킨스 인스턴스 출력
output "jenkins_instance_id" {
  description = "Jenkins 인스턴스 ID"
  value       = module.jenkins_instance.instance_id
}

output "jenkins_public_ip" {
  description = "Jenkins 인스턴스의 퍼블릭 IP"
  value       = module.jenkins_instance.public_ip
}
