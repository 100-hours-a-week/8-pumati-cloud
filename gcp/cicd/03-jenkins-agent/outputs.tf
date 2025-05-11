# Jenkins 에이전트 관련 출력값

output "jenkins_agent_mig_name" {
  description = "Jenkins 에이전트 MIG 이름"
  value       = module.jenkins_agent_mig.instance_group_name
}

output "jenkins_agent_instance_template" {
  description = "Jenkins 에이전트 인스턴스 템플릿 ID"
  value       = module.jenkins_agent_mig.instance_template_id
}

output "jenkins_agent_health_check_name" {
  description = "Jenkins 에이전트 헬스 체크 이름"
  value       = module.jenkins_agent_mig.health_check_name
}

output "jenkins_agent_size" {
  description = "Jenkins 에이전트 그룹 크기"
  value       = 2
}

output "firewall_rule_name" {
  description = "Jenkins 에이전트와 마스터 간 통신을 위한 방화벽 규칙 이름"
  value       = google_compute_firewall.jenkins_agent.name
}
