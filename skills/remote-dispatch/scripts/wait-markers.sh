#!/bin/bash
# 他のセッション（SSH 先を含む）の会話記録を監視し、完了の印 `[<ID>] DONE: ...` / `[<ID>] BLOCKED: ...` が
# すべて出たら終わる。司令塔はこれをバックグラウンドで動かし、終了通知を受けてから list_events で中身を読む。
#
# 使い方: wait-markers.sh <host|local> <セッションの cwd> <timeout 秒> <ID>...
#   例: wait-markers.sh pro /Users/me/repo/.claude/worktrees/foo 1800 T1005-1 T1005-2
# 終了コード: 0 = 全 ID 完了 / 2 = タイムアウト（未完了の ID を表示）/ その他 = 接続などのエラー
#
# 知らないと事故る前提:
# - SSH 先のセッションから SendMessage で送り返しても司令塔に届かない（実測）。だから会話記録を直接見る
# - 依頼文にも `[<ID>] DONE: <…>` という雛形が入るので、`: ` の直後が `<` の行は印とみなさない
# - 会話記録は ~/.claude/projects/<cwd の英数字以外を - にしたもの>/*.jsonl。見つからなければ全プロジェクトを探す
set -euo pipefail

if [[ ${1:-} != --here ]]; then
  host=${1:?host}; shift
  if [[ $host == local ]]; then
    exec bash "${BASH_SOURCE[0]}" --here "$@"
  fi
  exec ssh -o BatchMode=yes -o ServerAliveInterval=30 "$host" bash -s -- --here "$@" < "${BASH_SOURCE[0]}"
fi
shift
cwd=${1:?cwd}; timeout=${2:?timeout}; shift 2
(( $# > 0 )) || { echo "ID を 1 つ以上指定してください" >&2; exit 64; }
# ID は正規表現に埋め込むので、英数字と - だけに限る
for id in "$@"; do
  [[ $id =~ ^[A-Za-z0-9-]+$ ]] || { echo "ID は英数字と - だけにしてください: $id" >&2; exit 64; }
done

key=$(printf '%s' "$cwd" | LC_ALL=en_US.UTF-8 sed 's/[^A-Za-z0-9]/-/g')
dir=~/.claude/projects/$key
[[ -d $dir ]] || dir=~/.claude/projects
start=$(date +%s)

while :; do
  elapsed=$(( $(date +%s) - start ))
  # 監視を始める前に終わっていた作業も拾えるよう、窓は「経過時間 + 30 分」
  pending=()
  for id in "$@"; do
    hit=$(find "$dir" -name '*.jsonl' -mmin -$(( elapsed / 60 + 30 )) -print0 2>/dev/null |
      xargs -0 grep -lE "\\[$id\\] (DONE|BLOCKED): [^<]" 2>/dev/null | head -1 || true)
    [[ -n $hit ]] || pending+=("$id")
  done
  if (( ${#pending[@]} == 0 )); then
    echo "完了: $* （${elapsed} 秒）"
    exit 0
  fi
  if (( elapsed >= timeout )); then
    echo "タイムアウト（${elapsed} 秒）。未完了: ${pending[*]}"
    exit 2
  fi
  sleep 10
done
