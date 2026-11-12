#!/bin/bash
# dispatch.sh の判定・依頼の一覧・再接続・終了コードの確認。
# 偽の会話記録と依頼の一覧を一時 HOME に置く。ssh と sleep は PATH の先頭に置いた偽物に差し替える。
# 使い方: bash test-dispatch.sh
set -uo pipefail

d=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/dispatch.sh
home=$(mktemp -d)
trap 'rm -rf "$home"' EXIT
proj=$home/.claude/projects
ledger=$home/.claude/remote-dispatch/ledger.tsv
bin=$home/bin
mkdir -p "$proj/-w" "$proj/-stale" "$proj/-slept" "$bin"

# 偽の ssh: $home/ssh-fail の回数だけ 255 で失敗し、その後はリモートのコマンドをこのマシンで実行する
cat > "$bin/ssh" <<'EOF'
#!/bin/bash
n=$(cat "$HOME/ssh-fail" 2>/dev/null || echo 0)
if (( n > 0 )); then echo $(( n - 1 )) > "$HOME/ssh-fail"; echo "ssh: connect to host: Operation timed out" >&2; exit 255; fi
while [[ $1 == -o ]]; do shift 2; done
shift
exec bash -c "$1"
EOF
printf '#!/bin/bash\nexit 0\n' > "$bin/sleep"
chmod +x "$bin/ssh" "$bin/sleep"

run() { HOME=$home PATH=$bin:$PATH bash "$d" "$@"; }
line() { printf '{"message":{"role":"%s","content":[{"type":"text","text":"%s"}]}}\n' "$2" "$3" >> "$proj/$1/s.jsonl"; }
ago() { touch -t "$(date -v-"$2"H +%Y%m%d%H%M 2>/dev/null || date -d "$2 hours ago" +%Y%m%d%H%M)" "$1"; }

line -w assistant 'report\n[X-1] DONE: ok'
line -w assistant '[X-2] BLOCKED: need decision'
line -w assistant '[X-4] DONE: <1 行の要約>'
line -w user '[X-5] DONE: from user'
line -w assistant '[X-6] BLOCKED: need decision'
line -w assistant '[X-6] DONE: resolved'
printf '{"message":{"role":"assistant","content":[{"type":"text","text":"[X-7] DONE: old"}]}}\n' > "$proj/-w/old.jsonl"
ago "$proj/-w/old.jsonl" 2
# 印とみなさないもの: 文中の言及、ID が前後に長いもの、サブエージェントの記録、ツールの入出力
mkdir -p "$proj/-m/sess/subagents"
line -m assistant 'see [M-1] DONE: mentioned mid-line'
line -m assistant '[M-10] DONE: longer id'
line -m assistant '[XM-1] DONE: prefixed id'
printf '{"message":{"role":"assistant","content":[{"type":"text","text":"[M-2] DONE: from subagent"}]}}\n' > "$proj/-m/sess/subagents/agent-1.jsonl"
printf '{"message":{"role":"assistant","content":[{"type":"tool_use","name":"Write","input":{"content":"[M-3] DONE: in tool input"}}]}}\n' >> "$proj/-m/s.jsonl"
printf '{"message":{"role":"user","content":[{"type":"tool_result","content":[{"type":"text","text":"[M-3] DONE: tool output"}]}]}}\n' >> "$proj/-m/s.jsonl"
# 同じ行の text ブロックのあとに続くツールの入力は、その text ブロックの中ではない
printf '{"message":{"role":"assistant","content":[{"type":"text","text":"writing"},{"type":"tool_use","name":"Write","input":{"content":"draft\\n[M-5] DONE: in tool input"}}]}}\n' >> "$proj/-m/s.jsonl"
# 日本語の前置きのあとの行頭は印として数える
line -m assistant '報告です\n[M-4] DONE: 完了'
# 印を書かずに止まった子: 2 時間前から書き込みがない
line -stale assistant 'working...'
ago "$proj/-stale/s.jsonl" 2
# 司令塔のスリープ中に終わった子: 3 時間前に依頼し、2 時間前に DONE を書いた
line -slept assistant '[S-1] DONE: finished while the client slept'
ago "$proj/-slept/s.jsonl" 2

fail=0
expect() {
  local want=$1; shift
  run "$@" > "$home/out" 2>&1
  local got=$?
  if [[ $got == "$want" ]]; then echo "ok   exit=$got  $*"; else echo "FAIL exit=$got want=$want  $*: $(cat "$home/out")"; fail=1; fi
}
has() { if grep -q -- "$1" "$home/out"; then echo "ok   output has: $1"; else echo "FAIL output lacks: $1: $(cat "$home/out")"; fail=1; fi; }
lacks() { if grep -q -- "$1" "$home/out"; then echo "FAIL output has: $1: $(cat "$home/out")"; fail=1; else echo "ok   output lacks: $1"; fi; }

# --- add の入力検証 ---
expect 64 add 'bad id' local /w local_a
expect 64 add X-1 -oProxyCommand=evil /w local_a
expect 64 add X-1 local relative/path local_a
expect 64 add X-1 local /w 'bad session'
expect 64 add X-1 local "/w	tab" local_a
expect 64 add X-1 local /w
[[ ! -e $ledger ]] && echo "ok   rejected add writes nothing" || { echo "FAIL rejected add wrote the ledger"; fail=1; }
for i in 1 2 3 4 5 6 7; do expect 0 add X-$i local /w local_a; done
expect 65 add X-1 local /w local_a

# --- 印の判定 ---
expect 0 wait 0 X-1
has '実物'
expect 3 wait 0 X-1 X-2
expect 3 wait 0 X-2
expect 2 wait 0 X-1 X-3
expect 2 wait 0 X-4
expect 2 wait 0 X-5
expect 0 wait 0 X-6
# 子の cwd の記録は、古くても数える（回帰: add が子の最後の書き込みより 10 分以上遅れると、DONE を見落としていた。ID は一覧で一意）
expect 0 wait 0 X-7
# 子の cwd の記録がまだ無く、全プロジェクトを探すときだけ、依頼の時刻より前の記録を除く
printf '{"message":{"role":"assistant","content":[{"type":"text","text":"[F-1] DONE: old, other project"}]}}\n' >> "$proj/-w/old.jsonl"
ago "$proj/-w/old.jsonl" 2
line -w assistant '[F-2] DONE: fresh'
expect 0 add F-1 local /nodir local_f
expect 0 add F-2 local /nodir local_f
expect 2 wait 0 F-1
expect 0 wait 0 F-2
# 依頼の時刻が接続先の時計より 10 分以上先でも、-mmin を 0 以下にせず直近の記録は見る
line -w assistant '[F-3] DONE: client clock ahead'
printf '%s\tadd\tF-3\tlocal\t/nodir\tlocal_f\t-\n' "$(( $(date +%s) + 3600 ))" >> "$ledger"
expect 0 wait 0 F-3
expect 2 wait 0 X-2 X-3
has '未完了: X-3'
has 'BLOCKED: X-2'
for i in 1 2 3 4 5; do expect 0 add M-$i local /m local_m; done
expect 2 wait 0 M-1
expect 2 wait 0 M-2
expect 2 wait 0 M-3
expect 0 wait 0 M-4
expect 2 wait 0 M-5
expect 64 wait abc X-1
expect 64 wait 08 X-1
expect 64 wait 0
expect 65 wait 0 X-99

# --- 司令塔のスリープ中の完了（回帰: 監視を張り直すと、30 分より前の DONE を見落としていた）---
mkdir -p "$(dirname "$ledger")"
printf '%s\tadd\tS-1\tlocal\t/slept\tlocal_s\t-\n' "$(( $(date +%s) - 10800 ))" >> "$ledger"
expect 0 wait 0 S-1

# --- 書き込みが止まった子 ---
printf '%s\tadd\tST-1\tlocal\t/stale\tlocal_b\t-\n' "$(( $(date +%s) - 3600 ))" >> "$ledger"
expect 4 wait 0 ST-1
has '書き込みがありません'
printf '%s\tadd\tST-2\tlocal\t/stale\tlocal_b\t-\n' "$(( $(date +%s) - 3600 ))" >> "$ledger"
HOME=$home PATH=$bin:$PATH DISPATCH_STALL=0 bash "$d" wait 0 ST-2 > "$home/out" 2>&1; rc=$?
if [[ $rc == 2 ]]; then echo "ok   exit=2  DISPATCH_STALL=0 wait 0 ST-2"; else echo "FAIL exit=$rc want=2  DISPATCH_STALL=0: $(cat "$home/out")"; fail=1; fi
HOME=$home PATH=$bin:$PATH DISPATCH_STALL=x bash "$d" wait 0 ST-2 > /dev/null 2>&1; rc=$?
if [[ $rc == 64 ]]; then echo "ok   exit=64  DISPATCH_STALL=x"; else echo "FAIL exit=$rc want=64  DISPATCH_STALL=x"; fail=1; fi
# 動いている子（/w は書き込みが新しい）は、止まったとみなさない
expect 2 wait 0 X-3
# 依頼した直後は、子がまだ書き始めていないだけなので、止まったとみなさない（追加の指示を idle の子に送った直後）
expect 0 add ST-3 local /stale local_b
expect 2 wait 0 ST-3
# 新しい依頼と一緒に待つと、古い依頼だけでは止まったと判定しない
expect 2 wait 0 ST-1 ST-3

# --- 子が違う ID をまとめて待てない ---
expect 64 wait 0 X-1 ST-1

# --- ssh 越し: 切れても張り直す ---
expect 0 add R-1 pro /w local_r
line -w assistant '[R-1] DONE: remote ok'
echo 0 > "$home/ssh-fail"
expect 0 wait 0 R-1
echo 2 > "$home/ssh-fail"
expect 0 wait 600 R-1
has '接続できません'
# 復帰直後に時間切れになっていても、接続先を 1 回は調べてから終わる（スリープ中も時計は進み、復帰の直後は回線がまだ戻っていない）
echo 3 > "$home/ssh-fail"
expect 0 wait 0 R-1
# 続けて 4 回失敗したら、5 回目は試さずに終わる
echo 4 > "$home/ssh-fail"
expect 255 wait 0 R-1
echo 99 > "$home/ssh-fail"
expect 255 wait 0 R-1
has 'ssh -o BatchMode=yes'
echo 0 > "$home/ssh-fail"
expect 0 wait 0 R-1
# 空白や $ を含む cwd が、リモートのシェルで分割・実行されない
mkdir -p "$proj/-w--x---touch-pwned-"
line '-w--x---touch-pwned-' assistant '[Q-1] DONE: quoted'
expect 0 add Q-1 pro '/w $x $(touch pwned)' local_q
( cd "$home" && expect 0 wait 0 Q-1 )
[[ ! -e $home/pwned ]] && echo "ok   cwd is not evaluated remotely" || { echo "FAIL cwd was evaluated"; fail=1; }

# --- status と close ---
expect 0 status
has 'X-1.*DONE'
has 'X-2.*BLOCKED'
has 'X-3.*PENDING'
has 'ST-1.*PENDING.*書き込みなし'
lacks 'ST-3.*書き込みなし'
has 'R-1.*DONE.*pro.*local_r'
echo 99 > "$home/ssh-fail"
expect 0 status
has 'R-1.*UNREACHABLE'
has 'X-1.*DONE'
echo 0 > "$home/ssh-fail"
expect 64 close X-1
expect 65 close X-99 'no such id'
expect 0 close X-1 'PR を確認した'
expect 65 close X-1 'twice'
expect 65 wait 0 X-1
expect 65 add X-1 local /w local_a
expect 0 status
lacks '^X-1	'
has 'X-2.*BLOCKED'
for id in X-2 X-3 X-4 X-5 X-6 X-7 F-1 F-2 F-3 M-1 M-2 M-3 M-4 M-5 S-1 ST-1 ST-2 ST-3 R-1 Q-1; do run close $id done > /dev/null; done
expect 0 status
has '未完了の依頼はありません'
# 依頼の一覧は追記だけ。close した依頼も行として残る
n=$(grep -c . "$ledger")
if [[ $n == 42 ]]; then echo "ok   ledger keeps all 42 events"; else echo "FAIL ledger has $n events, want 42"; fail=1; fi

exit $fail
