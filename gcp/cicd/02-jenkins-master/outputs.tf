# 출력값 설정
output "jenkins_instance_name" {
  value = module.jenkins_master.instance_name
}

output "jenkins_static_ip" {
  value = module.jenkins_master.instance_external_ip
}

output "jenkins_url" {
  value = "http://${module.jenkins_master.instance_external_ip}:8080"
}