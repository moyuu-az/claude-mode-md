#!/bin/bash
# 他のセッション（SSH 先を含む）の会話記録を監視し、完了の印 `[<ID>] DONE: ...` / `[<ID>] BLOCKED: ...` が
# すべて出たら終わる。司令塔はこれをバックグラウンドで動かし、終了通知を受けてから list_events で中身を読む。
#
# 使い方: wait-markers.sh <host|local> <セッションの cwd> <timeout 秒> <ID>...
#   例: wait-markers.sh pro /Users/me/repo/.claude/worktrees/foo 1800 T1005-1
# 終了コード: 0 = 全 ID 完了 / 2 = タイムアウト（未完了の ID を表示）/ その他 = 接続などのエラー
#
# 知らないと事故る前提:
# - SSH 先のセッションから SendMessage で送り返しても司令塔に届かない（実測）。だから会話記録を直接見る
# - 印として数えるのは「assistant の text ブロックの行頭」だけ。依頼文（user / queue-operation の記録）、
#   ツールの入出力（Write の本文など）、文中での言及、サブエージェントの記録にも同じ文字列が出るため
# - 雛形の `[<ID>] DONE: <…>` が行頭に書かれても拾わないよう、`: ` の直後が `<` のものは印とみなさない
# - 会話記録は ~/.claude/projects/<cwd の英数字以外を - にしたもの>/*.jsonl。見つからなければ全プロジェクトを探す
set -euo pipefail

if [[ ${1:-} != --here ]]; then
  host=${1:?host}; shift
  if [[ $host == local ]]; then
    exec bash "${BASH_SOURCE[0]}" --here "$@"
  fi
  # ssh は引数を空白でつないでリモートのシェルに渡す。空白や $ を含む cwd が分割・実行されないようクォートする
  exec ssh -o BatchMode=yes -o ServerAliveInterval=30 "$host" "bash -s -- --here $(printf '%q ' "$@")" < "${BASH_SOURCE[0]}"
fi
shift
cwd=${1:?cwd}; timeout=${2:?timeout}; shift 2
(( $# > 0 )) || { echo "ID を 1 つ以上指定してください" >&2; exit 64; }
# 算術式に入れるので 10 進の整数に限る（`a[$(...)]` はコマンドとして実行され、`08` は比較が毎回失敗して終わらない）
[[ $timeout =~ ^(0|[1-9][0-9]*)$ ]] || { echo "timeout は秒数（整数）で指定してください: $timeout" >&2; exit 64; }
# ID は正規表現に埋め込むので、英数字と - だけに限る
for id in "$@"; do
  [[ $id =~ ^[A-Za-z0-9-]+$ ]] || { echo "ID は英数字と - だけにしてください: $id" >&2; exit 64; }
done
root=~/.claude/projects
# 無いまま待つと、host やユーザーの取り違えがタイムアウトに見えてしまう
[[ -d $root ]] || { echo "$root がありません（host かユーザーが違う可能性）" >&2; exit 66; }

key=$(printf '%s' "$cwd" | LC_ALL=en_US.UTF-8 sed 's/[^A-Za-z0-9]/-/g')
start=$(date +%s)

while :; do
  elapsed=$(( $(date +%s) - start ))
  # セッションの記録ディレクトリは最初の書き込みでできるので、毎回確かめる
  dir=$root/$key
  [[ -d $dir ]] || dir=$root
  # 監視を始める前に終わっていた作業も拾えるよう、窓は「経過時間 + 30 分」
  pending=()
  for id in "$@"; do
    # JSON 文字列の中で、先頭か改行（\n）の直後に印がある text ブロック
    pat='"type":"text","text":"(([^"\\]|\\.)*\\n)?\['"$id"'\] (DONE|BLOCKED): [^<]'
    hit=$(find "$dir" -name '*.jsonl' -not -path '*/subagents/*' -mmin -$(( elapsed / 60 + 30 )) -print0 2>/dev/null |
      xargs -0 grep -hE "$pat" 2>/dev/null | grep -cm1 '"role":"assistant"' || true)
    [[ $hit == 1 ]] || pending+=("$id")
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
