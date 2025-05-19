# 서비스 계정 생성법


# 1. cloudflared 상태 확인
sudo systemctl status cloudflared

# 2. 로그 확인
sudo journalctl -u cloudflared --no-pager -n 50

# 3. 설정 파일 확인
cat /etc/cloudflared/config.yml

# 4. 인증 파일 확인
ls -la /etc/cloudflared/
cat /etc/cloudflared/llm-tunnel.json

# 5. 환경 변수 확인
echo $TUNNEL_UUID

# 6. GCS 접근 권한 확인
gsutil ls gs://ktb8team-static-storage/cloudflare/

# 7. 방화벽 상태 확인
sudo iptables -L | grep 8000

# 8. 스타트업 스크립트 로그 확인
cat /var/log/startup-script.log | grep cloud

cat /var/log/image-watcher.log

tail -f /var/log/image-watcher.log

   systemctl status docker-image-watcher

   cat /opt/monitoring/watcher.sh 2>/dev/null || echo "파일이 존재하지 않음"

# 최근 100줄 로그 보기
journalctl -u docker-image-watcher.service -n 100 --no-pager

# 특정 시간 이후 로그 보기 (예: 1시간 전부터)
journalctl -u docker-image-watcher.service --since "1 hour ago"

# 모든 로그 보기 (양이 많을 수 있음)
journalctl -u docker-image-watcher.service --no-pager