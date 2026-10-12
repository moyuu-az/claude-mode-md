#!/bin/bash
# wait-markers.sh の判定と終了コードの確認。偽の会話記録を一時 HOME に置いて、timeout 0 で 1 回だけ判定させる。
# 使い方: bash test-wait-markers.sh
set -uo pipefail

w=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/wait-markers.sh
home=$(mktemp -d)
trap 'rm -rf "$home"' EXIT
dir=$home/.claude/projects/-w
mkdir -p "$dir"
line() { printf '{"message":{"role":"%s","content":[{"type":"text","text":"%s"}]}}\n' "$1" "$2" >> "$dir/s.jsonl"; }
line assistant 'report\n[X-1] DONE: ok'
line assistant '[X-2] BLOCKED: need decision'
line assistant '[X-4] DONE: <1 行の要約>'
line user '[X-5] DONE: from user'

fail=0
expect() {
  local want=$1; shift
  HOME=$home bash "$w" local /w 0 "$@" > /dev/null 2>&1
  local got=$?
  if [[ $got == "$want" ]]; then echo "ok   exit=$got  $*"; else echo "FAIL exit=$got want=$want  $*"; fail=1; fi
}
expect 0 X-1
expect 3 X-1 X-2
expect 3 X-2
expect 2 X-1 X-3
expect 2 X-4
expect 2 X-5
expect 64 'bad id'
exit $fail
