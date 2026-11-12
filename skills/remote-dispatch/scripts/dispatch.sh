#!/bin/bash
# 司令塔が他のセッション（SSH 先を含む）に振った依頼を一覧に記録し、完了の印
# `[<ID>] DONE: ...` / `[<ID>] BLOCKED: ...` が子の会話記録に出るのを待つ。
#
# 使い方:
#   dispatch.sh add <ID> <host|local> <子の cwd> <子の session id> [メモ]   依頼を一覧に記録する
#   dispatch.sh wait <timeout 秒> <ID>...                                    印が出そろうまで待つ（同じ子の ID だけ）
#   dispatch.sh status                                                       未完了の依頼すべての現状を 1 回調べる
#   dispatch.sh close <ID> <確かめたこと・後続の ID>                         依頼を閉じる
#
# wait の終了コード:
#   0 = 全 ID が DONE / 3 = BLOCKED を含む（子が返答を待っている）/ 2 = タイムアウト /
#   4 = 子の書き込みが止まっている / 255 = 接続できないまま時間切れ / 64 = 引数の誤り / 65 = 依頼の一覧と合わない / 66 = 接続先に会話記録がない
#
# 知らないと事故る前提:
# - 司令塔のマシンは頻繁にスリープし、接続先は起動し続ける。だから依頼を司令塔の記憶でなく一覧に残し、
#   wait は接続を張りっぱなしにせず 1 回ずつ調べる。ssh が切れても張り直し、スリープ中に出た印も依頼の時刻までさかのぼって見つける
# - 依頼の一覧は追記だけ（~/.claude/remote-dispatch/ledger.tsv）。書き換えないので、並行して書いても壊れず、閉じた依頼も経緯として残る
# - SSH 先のセッションから SendMessage で送り返しても司令塔に届かない（実測）。だから会話記録を直接見る
# - 印として数えるのは「assistant の text ブロックの行頭」だけ。依頼文（user / queue-operation の記録）、
#   ツールの入出力（Write の本文など）、文中での言及、サブエージェントの記録にも同じ文字列が出るため
# - 雛形の `[<ID>] DONE: <…>` が行頭に書かれても数えないよう、`: ` の直後が `<` のものは印とみなさない
# - 会話記録は ~/.claude/projects/<cwd の英数字以外を - にしたもの>/*.jsonl。見つからなければ全プロジェクトを探す
set -euo pipefail

# ssh 越しに標準入力から流し込まれたとき（bash -s）は BASH_SOURCE が空になる
self=${BASH_SOURCE[0]:-}
die() { local code=$1; shift; echo "$*" >&2; exit "$code"; }
valid_id() { [[ $1 =~ ^[A-Za-z0-9-]+$ ]] || die 64 "ID は英数字と - だけにしてください: $1"; }
# 算術式に入れるので 10 進の整数に限る（`a[$(...)]` はコマンドとして実行され、`08` は 8 進として失敗する）
valid_int() { [[ $2 =~ ^(0|[1-9][0-9]*)$ ]] || die 64 "$1 は秒数（整数）で指定してください: $2"; }

# ---- 接続先で動く部分: 会話記録を 1 回調べて、ID ごとの状態を出す ----
if [[ ${1:-} == --here ]]; then
  shift
  cwd=${1:?cwd}; since=${2:?since}; stall=${3:?stall}; shift 3
  valid_int since "$since"; valid_int stall "$stall"
  (( $# > 0 )) || die 64 "ID を 1 つ以上指定してください"
  for id in "$@"; do valid_id "$id"; done
  root=~/.claude/projects
  # 無いまま待つと、host やユーザーの取り違えがタイムアウトに見えてしまう
  [[ -d $root ]] || die 66 "$root がありません（host かユーザーが違う可能性）"
  key=$(printf '%s' "$cwd" | LC_ALL=en_US.UTF-8 sed 's/[^A-Za-z0-9]/-/g')
  # セッションの記録ディレクトリは最初の書き込みでできるので、毎回確かめる
  dir=$root/$key; own=1
  [[ -d $dir ]] || { dir=$root; own=; }
  # 子の cwd の記録は、古さで絞らない。ID は一覧で一意で、add が子の最後の書き込みより遅れても見落とさないため。
  # 全プロジェクトを探すときだけ、依頼の時刻までに絞る（10 分の余裕は 2 台の時計のずれの分。時計が逆転しても 1 分は見る）
  window=()
  if [[ -z $own ]]; then
    mmin=$(( ($(date +%s) - since) / 60 + 10 )); (( mmin > 0 )) || mmin=1
    window=(-mmin -"$mmin")
  fi
  for id in "$@"; do
    state=PENDING
    for kind in DONE BLOCKED; do
      # JSON 文字列の中で、先頭か改行（\n）の直後に印がある text ブロック
      pat='"type":"text","text":"(([^"\\]|\\.)*\\n)?\['"$id"'\] '"$kind"': [^<]'
      hit=$(find "$dir" -name '*.jsonl' -not -path '*/subagents/*' ${window[@]+"${window[@]}"} -print0 2>/dev/null |
        xargs -0 grep -hE "$pat" 2>/dev/null | grep -cm1 '"role":"assistant"' || true)
      if [[ $hit == 1 ]]; then state=$kind; break; fi
    done
    echo "id $id $state"
  done
  # サブエージェントが動いている間は親の記録が増えないので、subagents/ も含めて見る
  stalled=no
  if [[ -n $own ]] && (( stall > 0 )) &&
    [[ -z $(find "$dir" -name '*.jsonl' -mmin -$(( stall / 60 + 1 )) -print 2>/dev/null | head -1) ]]; then
    stalled=yes
  fi
  echo "stalled $stalled"
  exit 0
fi

# ---- 司令塔のマシンで動く部分 ----
dir=$HOME/.claude/remote-dispatch
ledger=$dir/ledger.tsv
# 子の書き込みがこの秒数止まったら、止まったとみなす。フォアグラウンドのコマンドの上限（10 分）より長くしてある
stall=${DISPATCH_STALL:-900}
valid_int DISPATCH_STALL "$stall"

usage() { sed -n '5,9p' "$self" | sed 's/^# //' >&2; exit 64; }

# close されていない add の行を、依頼した順に出す
open_rows() {
  [[ -f $ledger ]] || return 0
  awk -F'\t' '$2=="add"{row[$3]=$0; order[++n]=$3} $2=="close"{delete row[$3]}
    END{for(i=1;i<=n;i++) if(order[i] in row) print row[order[i]]}' "$ledger"
}
row_of() { open_rows | awk -F'\t' -v id="$1" '$3==id'; }

# 接続先で 1 回調べる。接続は毎回張って閉じる（張りっぱなしの接続は、司令塔がスリープすると、エラーを出さずに切れる）
check() {
  local host=$1; shift
  if [[ $host == local ]]; then
    bash "$self" --here "$@" < /dev/null
  else
    # ssh は引数を空白でつないでリモートのシェルに渡す。空白や $ を含む cwd が分割・実行されないようクォートする
    ssh -o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=15 -o ServerAliveCountMax=2 \
      "$host" "bash -s -- --here $(printf '%q ' "$@")" < "$self"
  fi
}

cmd=${1:-}; [[ -n $cmd ]] && shift
case $cmd in
add)
  (( $# >= 4 )) || usage
  id=$1; host=$2; cwd=$3; session=$4; shift 4; note=${*:--}
  valid_id "$id"
  # host は ssh にそのまま渡すので、`-o...` として解釈される形を通さない
  [[ $host =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || die 64 "host は ssh の Host 名か local にしてください: $host"
  [[ $cwd == /* ]] || die 64 "cwd は絶対パスにしてください: $cwd"
  [[ $session =~ ^[A-Za-z0-9_-]+$ ]] || die 64 "session id は英数字と _ - だけにしてください: $session"
  case $cwd$note in *$'\t'*|*$'\n'*) die 64 "cwd とメモにタブ・改行は使えません" ;; esac
  mkdir -p "$dir"
  # 同じ ID を使い回すと、前回の印で wait がすぐ終わる
  if [[ -f $ledger ]] && awk -F'\t' -v id="$id" '$3==id{f=1} END{exit !f}' "$ledger"; then
    die 65 "ID $id は使用済みです。追加の指示・やり直しにも新しい ID を振ってください"
  fi
  printf '%s\tadd\t%s\t%s\t%s\t%s\t%s\n' "$(date +%s)" "$id" "$host" "$cwd" "$session" "$note" >> "$ledger"
  echo "記録: $id（$host $session）"
  ;;

close)
  (( $# >= 2 )) || usage
  id=$1; shift; note=$*
  valid_id "$id"
  case $note in *$'\t'*|*$'\n'*) die 64 "メモにタブ・改行は使えません" ;; esac
  [[ -n $(row_of "$id") ]] || die 65 "未完了の依頼に $id はありません"
  printf '%s\tclose\t%s\t-\t-\t-\t%s\n' "$(date +%s)" "$id" "$note" >> "$ledger"
  echo "完了: $id"
  ;;

status)
  rows=$(open_rows)
  [[ -n $rows ]] || { echo "未完了の依頼はありません"; exit 0; }
  now=$(date +%s); down=' '
  printf 'ID\t状態\thost\tsession\t依頼から\tcwd\tメモ\n'
  while IFS=$'\t' read -r t _ id host cwd session note; do
    if [[ $down == *" $host "* ]]; then
      state=UNREACHABLE
    else
      rc=0; out=$(check "$host" "$cwd" "$t" "$stall" "$id" 2>&1) || rc=$?
      case $rc in
        0)
          state=$(awk -v id="$id" '$1=="id" && $2==id {print $3}' <<< "$out")
          [[ $state == PENDING && $out == *"stalled yes"* ]] && (( now - t >= stall )) && state="PENDING（$(( stall / 60 )) 分以上書き込みなし）"
          ;;
        # 同じ host の残りを 1 件ずつ 10 秒待たない
        255) state=UNREACHABLE; down="$down$host " ;;
        *) state="ERROR($rc)" ;;
      esac
    fi
    printf '%s\t%s\t%s\t%s\t%s 分\t%s\t%s\n' "$id" "${state:-ERROR}" "$host" "$session" "$(( (now - t) / 60 ))" "$cwd" "$note"
  done <<< "$rows"
  echo "DONE は実物（PR・git log・CI）を確かめてから close。BLOCKED は結論を新しい ID で子に送ってから close。書き込みなし・UNREACHABLE は SKILL.md の「復帰したとき」へ"
  ;;

wait)
  (( $# >= 2 )) || usage
  timeout=$1; shift
  valid_int timeout "$timeout"
  host=; cwd=; since=; latest=0
  for id in "$@"; do
    valid_id "$id"
    row=$(row_of "$id")
    [[ -n $row ]] || die 65 "未完了の依頼に $id はありません。先に add で記録してください"
    IFS=$'\t' read -r t _ _ h c _ <<< "$row"
    if [[ -z $host ]]; then host=$h; cwd=$c; since=$t; fi
    [[ $h == "$host" && $c == "$cwd" ]] || die 64 "別の子の ID はまとめて待てません（子ごとに 1 本ずつ動かす）: $id"
    (( t < since )) && since=$t
    (( t > latest )) && latest=$t
  done
  start=$(date +%s); fails=0
  while :; do
    rc=0; out=$(check "$host" "$cwd" "$since" "$stall" "$@" 2>&1) || rc=$?
    elapsed=$(( $(date +%s) - start ))
    if (( rc == 0 )); then
      fails=0; pending=; blocked=
      for id in "$@"; do
        case $(awk -v id="$id" '$1=="id" && $2==id {print $3}' <<< "$out") in
          DONE) ;;
          BLOCKED) blocked="$blocked $id" ;;
          *) pending="$pending $id" ;;
        esac
      done
      if [[ -z $pending ]]; then
        # BLOCKED は子からの質問。DONE と同じ 0 で返すと、返答し忘れても司令塔が気づけない
        if [[ -n $blocked ]]; then
          echo "BLOCKED:$blocked（${elapsed} 秒）。子は返答を待っている。結論を新しい ID で子に送り、add と wait をやり直してから close する"
          exit 3
        fi
        echo "DONE: $*（${elapsed} 秒）。実物を確かめてから close する"
        exit 0
      fi
      # 依頼した直後は、子がまだ書き始めていないだけなので、止まったとみなさない
      if [[ $out == *"stalled yes"* ]] && (( $(date +%s) - latest >= stall )); then
        echo "子の書き込みがありません（$(( stall / 60 )) 分以上）。未完了:$pending${blocked:+ / BLOCKED:$blocked}。list_events と get_session で、許可待ち・印を書かずに停止・長い処理の途中のどれかを確かめる"
        exit 4
      fi
    elif (( rc == 255 )); then
      # 司令塔がスリープしていたか、回線が切れている。印は接続先に残るので、つながるまで待てば取りこぼさない
      (( fails > 0 )) || echo "$host に接続できません。つながるまで試し続けます"
      fails=$(( fails + 1 ))
    else
      echo "$out" >&2
      exit "$rc"
    fi
    # 時間切れの判定は、調べたあとにする。スリープ中も時計は進むので、先に判定すると復帰した瞬間に何も見ずに終わる
    if (( elapsed >= timeout )); then
      if (( rc == 255 )); then
        # スリープから戻った直後は回線がまだ戻っていない。続けて 4 回（約 1 分）失敗するまでは、接続先を見ずに終わらない
        if (( fails < 4 )); then sleep 15; continue; fi
        echo "$host に接続できないまま時間切れ（${elapsed} 秒）。\`ssh -o BatchMode=yes -o ConnectTimeout=10 $host true\` で確かめる"
        exit 255
      fi
      echo "タイムアウト（${elapsed} 秒）。未完了:$pending${blocked:+ / BLOCKED:$blocked}"
      exit 2
    fi
    sleep 15
  done
  ;;

*) usage ;;
esac
