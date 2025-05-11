생성 후 마스터 잘 떴는지 확인


jenkins_instance_name = "jenkins-master"
jenkins_static_ip = "34.47.66.109"
jenkins_url = "http://34.47.66.109:8080"

스타트업 로그 보는 법
sudo cat /var/log/syslog | grep startup-script

전체 로그
sudo less /var/log/syslog

필터링 예시
sudo grep "startup-script" /var/log/syslog


로그 보기
# 실시간 보기
sudo journalctl -u google-startup-scripts.service -f

# 과거 전체 로그 검색
sudo journalctl -u google-startup-scripts.service

sudo grep startup-script /var/log/syslog

에러 메세지만 골라보기

sudo journalctl -u google-startup-scripts.service -o cat \
  | grep -i 'error\|failed'
