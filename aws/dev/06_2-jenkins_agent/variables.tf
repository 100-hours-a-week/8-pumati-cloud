#==============================================================================
# Jenkins 에이전트 Variables (Secret만 관리)
#==============================================================================

# 🔑 Jenkins 에이전트 Secret (Jenkins UI에서 발급받은 값)
variable "jenkins_agent_secret" {
  description = "Jenkins에서 발급받은 에이전트 Secret 키"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.jenkins_agent_secret) > 10
    error_message = "Jenkins Secret은 10글자 이상이어야 합니다."
  }
  
  # secrets.auto.tfvars 파일에서 설정
  # jenkins_agent_secret = "526600b00d1eb4754ddca64f5d3c65d8ecc346c949aa2972d73b055525c2410a"
} 