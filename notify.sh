#!/bin/bash

EVENT_TYPE="${1:-stop}"
PROJECT_NAME=$(basename "$PWD")
TIMESTAMP=$(date +"%H:%M:%S")

# Read stdin JSON
INPUT=""
if [ ! -t 0 ]; then
  INPUT=$(cat)
fi

exec < /dev/null

case "$EVENT_TYPE" in
  notification)
    nohup terminal-notifier \
      -title "Claude Code" \
      -subtitle "${PROJECT_NAME}" \
      -message "入力待ちです (${TIMESTAMP})" \
      -sound "Glass" \
      -group "claude-code-notify" \
      -activate "com.mitchellh.ghostty" > /dev/null 2>&1 &
    ;;
esac
