#!/bin/bash

# config.sh를 이미 설정하지 않았다면 설정
if [ ! -f .runner ]; then
  ./config.sh --url "$REPO_URL" --token "$RUNNER_TOKEN" --unattended --name $(hostname)
fi

./run.sh
