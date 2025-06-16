
log_message "▶ 도커 이미지 자동 업데이트 감시 서비스 설정 중..."

# 환경 설정
KEY_FILE="/etc/sa/ktb8team-reader.json"
IMAGE="asia-east1-docker.pkg.dev/ktb8team-458916/ktb8team/dev/ai"
NAME="ai"
LOGFILE="/var/log/image-watcher.log"
# WEBHOOK_URL_AI 는 스타트업 스크립트에서 넘겨줌.

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "[$TIMESTAMP] ▶ AI 서비스 이미지 자동 업데이트 감시 시작" | tee -a "$LOGFILE"

# 인증 설정
gcloud auth activate-service-account --key-file="$KEY_FILE" >> "$LOGFILE" 2>&1
gcloud auth configure-docker asia-east1-docker.pkg.dev --quiet >> "$LOGFILE" 2>&1

# jq와 bc 설치 확인 및 설치
if ! command -v jq &> /dev/null; then
    apt-get update && apt-get install -y jq
fi

if ! command -v bc &> /dev/null; then
    apt-get update && apt-get install -y bc
fi

while true; do
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  
  # 1. 원격 저장소에서 이미지 메타데이터 확인 (pull 없이)
  REMOTE_DIGEST=$(gcloud artifacts docker images list "$IMAGE" --format="value(DIGEST)" --limit=1 2>/dev/null || echo "")
  
  # 2. 컨테이너 실행 중인지 확인
  CONTAINER_RUNNING=$(docker ps -q -f name="^$NAME$")
  
  if [ -z "$CONTAINER_RUNNING" ]; then
    # 컨테이너가 실행 중이 아니면 pull 후 시작
    echo "[$TIMESTAMP] 컨테이너가 실행 중이 아님. 이미지 pull 및 시작 중..." | tee -a "$LOGFILE"
    
    if docker pull "$IMAGE:latest" > /dev/null 2>&1; then
      if docker run --gpus all --shm-size=8g -d --restart unless-stopped --name "$NAME" -p 8080:8080 "$IMAGE:latest"; then
        echo "[$TIMESTAMP] ✅ 컨테이너 시작 성공" | tee -a "$LOGFILE"
        
        # 현재 시간 (KST)
        CURRENT_TIME=$(TZ='Asia/Seoul' date '+%Y년 %m월 %d일 %H:%M:%S')
        
        # 이미지 정보 가져오기
        IMAGE_INFO=$(docker inspect "$IMAGE:latest" 2>/dev/null)
        IMAGE_CREATED=$(echo "$IMAGE_INFO" | jq -r '.[0].Created')
        IMAGE_SIZE=$(echo "$IMAGE_INFO" | jq -r '.[0].Size')
        IMAGE_SIZE_GB=$(echo "scale=2; $IMAGE_SIZE/1024/1024/1024" | bc)
        
        # 깃헙 정보 가져오기 (CI에서 추가한 레이블)
        GIT_AUTHOR=$(docker inspect "$IMAGE:latest" | jq -r '.[0].Config.Labels.git_author // "알 수 없음"')
        GIT_COMMIT=$(docker inspect "$IMAGE:latest" | jq -r '.[0].Config.Labels.git_commit // "알 수 없음"')
        GIT_MESSAGE=$(docker inspect "$IMAGE:latest" | jq -r '.[0].Config.Labels.git_message // "알 수 없음"')
        
        # Discord 웹훅 페이로드 - 배포 성공
        curl -H "Content-Type: application/json" -X POST -d '{
          "username": "🤖 PUMATI 인공지능 배포 봇",
          "avatar_url": "https://avatars.githubusercontent.com/u/583231",
          "content": "🌟 **'"$GIT_AUTHOR"'** 님이 푸시한 AI 서비스가 배포되었습니다! 🚀",
          "embeds": [{
            "title": "✅ AI 서비스 배포 성공! 🎉 🎊",
            "color": 3066993,
            "description": "🔥 **'"$GIT_AUTHOR"'** 님이 푸시한 코드의 Docker 이미지 빌드 및 배포가 성공적으로 완료되었습니다! 🙌",
            "fields": [
              {
                "name": "👨‍💻 푸시한 사람 👑",
                "value": "```fix\n'"$GIT_AUTHOR"'\n```",
                "inline": false
              },
              {
                "name": "📝 커밋 메시지 💬",
                "value": "📌 '"$GIT_MESSAGE"' 📎",
                "inline": false
              },
              {
                "name": "🖥️ 호스트 정보 💻",
                "value": "```fix\n'"$(hostname)"'\n```",
                "inline": false
              },
              {
                "name": "🕒 배포 시간 ⏰",
                "value": "🗓️ '"$CURRENT_TIME"' 🕰️",
                "inline": true
              },
              {
                "name": "🖼️ 이미지 정보 📦",
                "value": "```\n이미지: '"$IMAGE"'\n크기: '"$IMAGE_SIZE_GB"' GB\n커밋: '"$GIT_COMMIT"'\n```",
                "inline": false
              },
              {
                "name": "🌐 서비스 URL 🔗",
                "value": "http://'"$(hostname -I | awk '{print $1}')"':8080",
                "inline": false
              }
            ],
            "thumbnail": {
              "url": "https://robohash.org/'"$GIT_AUTHOR"'?set=set3&size=128x128"
            },
            "footer": {
              "text": "🏆 ktb8team AI 서비스 배포 시스템 - '"$(hostname)"' 🛠️"
            }
          }]
        }' "$WEBHOOK_URL_AI"
      else
        echo "[$TIMESTAMP] ❌ 컨테이너 시작 실패" | tee -a "$LOGFILE"
      fi
    else
      echo "[$TIMESTAMP] ❌ 이미지 pull 실패" | tee -a "$LOGFILE"
    fi
  else
    # 3. 로컬 이미지 정보 가져오기
    LOCAL_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' "$IMAGE:latest" 2>/dev/null | grep -o 'sha256:[a-f0-9]*' || echo "")
    
    echo "[$TIMESTAMP] 원격: $REMOTE_DIGEST" >> "$LOGFILE"
    echo "[$TIMESTAMP] 로컬: $LOCAL_DIGEST" >> "$LOGFILE"
    
    # 4. digest가 다를 경우에만 pull 및 재시작
    if [ -n "$REMOTE_DIGEST" ] && [ -n "$LOCAL_DIGEST" ] && [ "$REMOTE_DIGEST" != "$LOCAL_DIGEST" ]; then
      echo "[$TIMESTAMP] 새 이미지 감지됨. pull 및 재시작 중..." | tee -a "$LOGFILE"
      
      # 새 이미지 pull
      if docker pull "$IMAGE:latest" > /dev/null 2>&1; then
        # 기존 컨테이너 중지 및 제거
        docker stop "$NAME" >/dev/null 2>&1
        docker rm "$NAME" >/dev/null 2>&1
        
        # 새 컨테이너 실행
        if docker run --gpus all --shm-size=8g -d --restart unless-stopped --name "$NAME" -p 8080:8080 "$IMAGE:latest"; then
          echo "[$TIMESTAMP] ✅ 새 이미지로 컨테이너 재시작 성공" | tee -a "$LOGFILE"
          
          # 현재 시간 (KST)
          CURRENT_TIME=$(TZ='Asia/Seoul' date '+%Y년 %m월 %d일 %H:%M:%S')
          
          # 이미지 정보 가져오기
          IMAGE_INFO=$(docker inspect "$IMAGE:latest" 2>/dev/null)
          IMAGE_CREATED=$(echo "$IMAGE_INFO" | jq -r '.[0].Created')
          IMAGE_SIZE=$(echo "$IMAGE_INFO" | jq -r '.[0].Size')
          IMAGE_SIZE_GB=$(echo "scale=2; $IMAGE_SIZE/1024/1024/1024" | bc)
          
          # 깃헙 정보 가져오기 (CI에서 추가한 레이블)
          GIT_AUTHOR=$(docker inspect "$IMAGE:latest" | jq -r '.[0].Config.Labels.git_author // "알 수 없음"')
          GIT_COMMIT=$(docker inspect "$IMAGE:latest" | jq -r '.[0].Config.Labels.git_commit // "알 수 없음"')
          GIT_MESSAGE=$(docker inspect "$IMAGE:latest" | jq -r '.[0].Config.Labels.git_message // "알 수 없음"')
          
          # Discord 웹훅 페이로드 - 업데이트 성공
          curl -H "Content-Type: application/json" -X POST -d '{
            "username": "🤖 PUMATI 인공지능 배포 봇",
            "avatar_url": "https://avatars.githubusercontent.com/u/583231",
            "content": "🌟 **'"$GIT_AUTHOR"'** 님이 푸시한 AI 서비스가 업데이트되었습니다! 🚀",
            "embeds": [{
              "title": "✅ AI 서비스 업데이트 성공! 🎉 🎊",
              "color": 3066993,
              "description": "🔥 **'"$GIT_AUTHOR"'** 님이 푸시한 코드의 Docker 이미지로 업데이트가 성공적으로 완료되었습니다! 🙌",
              "fields": [
                {
                  "name": "👨‍💻 푸시한 사람 👑",
                  "value": "```fix\n'"$GIT_AUTHOR"'\n```",
                  "inline": false
                },
                {
                  "name": "📝 커밋 메시지 💬",
                  "value": "📌 '"$GIT_MESSAGE"' 📎",
                  "inline": false
                },
                {
                  "name": "🖥️ 호스트 정보 💻",
                  "value": "```fix\n'"$(hostname)"'\n```",
                  "inline": false
                },
                {
                  "name": "🕒 업데이트 시간 ⏰",
                  "value": "🗓️ '"$CURRENT_TIME"' 🕰️",
                  "inline": true
                },
                {
                  "name": "🖼️ 이미지 정보 📦",
                  "value": "```\n이미지: '"$IMAGE"'\n크기: '"$IMAGE_SIZE_GB"' GB\n커밋: '"$GIT_COMMIT"'\n```",
                  "inline": false
                },
                {
                  "name": "🌐 서비스 URL 🔗",
                  "value": "http://'"$(hostname -I | awk '{print $1}')"':8080",
                  "inline": false
                }
              ],
              "thumbnail": {
                "url": "https://robohash.org/'"$GIT_AUTHOR"'?set=set3&size=128x128"
              },
              "footer": {
                "text": "🏆 ktb8team AI 서비스 배포 시스템 - '"$(hostname)"' 🛠️"
              }
            }]
          }' "$WEBHOOK_URL_AI"
        else
          echo "[$TIMESTAMP] ❌ 컨테이너 재시작 실패" | tee -a "$LOGFILE"
        fi
      else
        echo "[$TIMESTAMP] ❌ 새 이미지 pull 실패" | tee -a "$LOGFILE"
      fi
    else
      echo "[$TIMESTAMP] 변경 없음" >> "$LOGFILE"
    fi
  fi

  # 5. 정리 - 사용하지 않는 이미지 삭제
  if [ $((RANDOM % 10)) -eq 0 ]; then  # 약 10% 확률로 실행 (무작위)
    echo "[$TIMESTAMP] 🧹 사용하지 않는 이미지 정리 중..." >> "$LOGFILE"
    docker image prune -f >> "$LOGFILE" 2>&1
  fi

  sleep 30  # 30초 대기
done

