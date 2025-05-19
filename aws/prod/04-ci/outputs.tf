# ------------------------------------------------------------
# Jenkins 인스턴스 출력값
# ------------------------------------------------------------
output "jenkins_instance_id" {
  description = "Jenkins 인스턴스 ID"
  value       = module.jenkins.instance_id
}

output "jenkins_public_ip" {
  description = "Jenkins 인스턴스 퍼블릭 IP"
  value       = module.jenkins.public_ip
}

output "jenkins_private_ip" {
  description = "Jenkins 인스턴스 프라이빗 IP"
  value       = module.jenkins.private_ip
} 