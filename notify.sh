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
  stop)
    # Extract last assistant message as summary (truncate to 100 chars)
    SUMMARY=$(echo "$INPUT" | jq -r '.last_assistant_message // empty' 2>/dev/null | head -c 100)
    MSG="${SUMMARY:-タスク完了} (${TIMESTAMP})"

    nohup terminal-notifier \
      -title "Claude Code" \
      -subtitle "${PROJECT_NAME}" \
      -message "$MSG" \
      -sound "Bottle" \
      -group "claude-code-stop" \
      -activate "com.mitchellh.ghostty" > /dev/null 2>&1 &
    ;;
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
