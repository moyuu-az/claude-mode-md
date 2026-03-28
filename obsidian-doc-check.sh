#!/bin/bash
# Obsidian documentation check for Claude Code Stop hook
# Checks if any .md files were created/modified in the vault during this session

VAULT="/Users/moyu/Library/CloudStorage/GoogleDrive-<email>/マイドライブ/Obsidian/Code-Notizbuch"

# Check for .md files modified in the last 60 minutes (excluding Templates/ and .obsidian/)
RECENT_FILES=$(find "$VAULT" -name "*.md" -not -path "*/Templates/*" -not -path "*/.obsidian/*" -not -path "*/Index/*" -not -name "ようこそ.md" -mmin -60 2>/dev/null | wc -l | tr -d ' ')

if [ "$RECENT_FILES" -eq 0 ]; then
  cat <<'EOF'
{
  "decision": "block",
  "reason": "Obsidian ドキュメント化チェック: Code-Notizbuch vault に直近60分以内のドキュメントがありません。作業内容を Obsidian に記録してください。\n\nobsidian-doc スキル (~/. claude/skills/obsidian-doc/SKILL.md) に従って、適切なドキュメント (Session/Decision/Feature/Bug/Research) を vault に書き出してください。\n\nVault パス: /Users/moyu/Library/CloudStorage/GoogleDrive-<email>/マイドライブ/Obsidian/Code-Notizbuch"
}
EOF
else
  echo '{}'
fi
