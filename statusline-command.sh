#!/bin/bash
# Claude Code Status Line - 3-line display with rate limits
# Reads JSON from stdin, outputs ANSI-colored 3-line status

input=$(cat)

# ── Extract from stdin JSON ──
MODEL=$(echo "$input" | jq -r '.model.display_name // "Unknown"' 2>/dev/null)
DIR=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // "."' 2>/dev/null)

# Context window usage
# used_percentage は小数で来ることがある（例: 12.5）。bash の (( )) は整数専用なので必ず切り捨てる
CTX=$(echo "$input" | jq -r '.context_window.used_percentage // 0 | floor' 2>/dev/null)
[[ "$CTX" == "null" || -z "$CTX" ]] && CTX=0

# Lines changed from cost section
ADD=$(echo "$input" | jq -r '.cost.total_lines_added // 0' 2>/dev/null)
DEL=$(echo "$input" | jq -r '.cost.total_lines_removed // 0' 2>/dev/null)
[[ "$ADD" == "null" ]] && ADD=0
[[ "$DEL" == "null" ]] && DEL=0

# Git info (cd to cwd to get correct branch, especially in worktrees)
BRANCH="N/A"
WORKTREE=""
if cd "$DIR" 2>/dev/null && git rev-parse --git-dir >/dev/null 2>&1; then
  BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
  [[ -z "$BRANCH" ]] && BRANCH="detached"
  # Detect worktree: if .git is a file (not a directory), we're in a linked worktree
  TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -n "$TOPLEVEL" && -f "$TOPLEVEL/.git" ]]; then
    WORKTREE=" [wt]"
  fi
  # Fallback: get diff stats if not provided
  if [[ "$ADD" == "0" && "$DEL" == "0" ]]; then
    read -r ADD DEL < <(git diff --numstat 2>/dev/null | awk '{a+=$1;d+=$2} END{printf "%d %d",a+0,d+0}')
  fi
fi

# ── ANSI Colors (24-bit true color) ──
cG='\033[38;2;151;201;195m'  # green  #97C9C3
cY='\033[38;2;229;192;123m'  # yellow #E5C07B
cR='\033[38;2;224;108;117m'  # red    #E06C75
cD='\033[38;2;74;88;92m'     # gray   #4A585C
cN='\033[0m'                  # reset

# Color for percentage
cc() {
  local p=${1:-0}
  (( p <= 49 )) && printf "$cG" && return
  (( p <= 79 )) && printf "$cY" && return
  printf "$cR"
}

# Progress bar: 10 segments using filled/empty blocks
pb() {
  local f=$(( ${1:-0} / 10 )) bar=""
  (( f > 10 )) && f=10; (( f < 0 )) && f=0
  for ((i=0;i<f;i++)); do bar+="▰"; done
  for ((i=f;i<10;i++)); do bar+="▱"; done
  echo "$bar"
}

# ── Rate Limits (from stdin JSON, already provided) ──
# used_percentage は小数で来ることがある。整数演算 (cc/pb) のため floor で切り捨てる
fp=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // 0 | floor' 2>/dev/null)
sp=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // 0 | floor' 2>/dev/null)
[[ "$fp" == "null" || -z "$fp" ]] && fp=0
[[ "$sp" == "null" || -z "$sp" ]] && sp=0

fr="" sr=""

# 5-hour reset time (epoch seconds from JSON)
f_epoch=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty' 2>/dev/null)
if [[ -n "$f_epoch" && "$f_epoch" != "null" ]]; then
  h=$(TZ=Asia/Tokyo date -r "$f_epoch" "+%l" 2>/dev/null | tr -d ' ')
  ap=$(TZ=Asia/Tokyo date -r "$f_epoch" "+%p" 2>/dev/null | tr '[:upper:]' '[:lower:]')
  [[ -n "$h" ]] && fr="Reset ${h}${ap}"
fi

# 7-day reset time (epoch seconds from JSON)
s_epoch=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty' 2>/dev/null)
if [[ -n "$s_epoch" && "$s_epoch" != "null" ]]; then
  m=$(TZ=Asia/Tokyo date -r "$s_epoch" "+%b" 2>/dev/null)
  d=$(TZ=Asia/Tokyo date -r "$s_epoch" "+%e" 2>/dev/null | tr -d ' ')
  h=$(TZ=Asia/Tokyo date -r "$s_epoch" "+%l" 2>/dev/null | tr -d ' ')
  ap=$(TZ=Asia/Tokyo date -r "$s_epoch" "+%p" 2>/dev/null | tr '[:upper:]' '[:lower:]')
  [[ -n "$h" ]] && sr="Reset ${m}${d} ${h}${ap}"
fi

# ── Output 3 lines ──
S="${cD}|${cN}"

printf "%b\n" "${MODEL} ${S} $(cc $CTX)${CTX}%${cN} ${S} +${ADD}/-${DEL} ${S} ${BRANCH}${WORKTREE}"
printf "%b\n" "5h $(cc $fp)$(pb $fp) ${fp}%${cN}  ${fr}"
printf "%b"   "7d $(cc $sp)$(pb $sp) ${sp}%${cN}  ${sr}"
