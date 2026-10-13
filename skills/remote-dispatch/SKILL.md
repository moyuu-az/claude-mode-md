---
name: remote-dispatch
description: Use when the user wants this session to act as a dispatcher — handing tasks to other Claude Desktop sessions in this app (especially SSH sessions running on another Mac), running them in parallel, and collecting the results. Triggers include「Pro で動かして」「別のマシン（セッション）に振って」「並行して進めて」「司令塔として」「リモートのセッションに指示して」.
---

# 別セッションへの作業の振り分け（司令塔）

このセッションを司令塔にして、他のセッション（別マシンで動く SSH セッションを含む）に作業を振り、完了を待って結果をまとめる。
司令塔は指示・監視・検証だけを行い、作業そのものはしない。

## 前提（実測済み）
- 作業用のセッションは、司令塔が `start_session` で立てられる。SSH 先にも立てられる（2026-10-12 に `target: "ssh"` で確認）
- 立てたセッションは司令塔の linked session になる。`list_sessions {"linked": true}` で cwd・branch・isRunning を見られる
- 子が 1 ターン終えると、アプリが司令塔に知らせる（「finished a turn」の通知や `<side-sessions-event>`）。ただし司令塔が作業中だと、通知は次のターンまで届かないことがある
- 子への追加の指示は `SendMessage`（`to` は子の `local_...` ID）で送る。子が作業中なら queued になり、今の作業が終わってから実行される
- 子は「同僚からの依頼」として、自分の権限の範囲で動く。許可待ちになると止まり、司令塔からは許可できない
- **子が SendMessage で送り返しても、司令塔には届かない（SSH 先から）。** 結果は子の返信を `list_events` で読む
- SSH 先がスリープしたり回線が切れたりすると、子はツール呼び出しの途中で止まり、印を書かないまま idle になる。監視スクリプトは終了コード 255 で終わる（2026-10-12、2 つの子が同じ時刻に止まり、ssh が port 22 でタイムアウトした）
- `ssh <host> claude -p` で直接動かす方法は使わない（SSH 経由ではキーチェーンを読めず「Not logged in」になる）

## 手順
1. **立てる場所を決める。** `list_start_targets` で SSH の接続名（`host`）と、接続先の最近のフォルダを確かめる。接続名は推測しない。
   - 1 タスク = 1 セッション = 1 worktree。同じ worktree に別のタスクを重ねない
   - repo の作業ツリーは、別の作業のブランチに切り替わっていることがある。立てる前に `ssh <ssh の Host> git -C <repo> branch --show-current`（Host は手順 4 を参照）で確かめ、`source_branch` に `main` などの起点を明示する
2. **ID を振る。** 日付を含む一意の ID にする（例: `T1005-1`）。追加の指示・やり直し・BLOCKED への返答も、毎回新しい ID にする。同じ ID だと前回の印で監視がすぐ終わる。送る文の先頭には `[<新しい ID>]` を付け、雛形の最後の 3 行（印の書き方と、SendMessage で送らないこと）も新しい ID で付け直す。付けないと、子は前の ID で印を書き、新しい ID の監視はタイムアウトまで終わらない
3. **立てて指示する。** `start_session` を次の値で呼ぶ。
   - `initiation: "user_asked"`、`context: "fresh"`、`target: "ssh"`、`host`（手順 1 の接続名）、`cwd`（接続先の repo の絶対パス）、`use_worktree: true`、`source_branch`、`branch_name`
   - このマシンに立てるときは `target` と `host` を省き、`cwd` にこのマシンの repo を渡す
   - `background` には全体の目的・他の子の担当・共有する制約（CPU や全体テストの順番など）を書く
   - `prompt` は次の雛形にする

   ```
   [<ID>] 司令塔からの作業依頼です。
   目的: <何を達成するか>
   範囲: <触ってよい場所・ブランチ。push や PR を作るかどうか>
   完了条件: <テストが通る、など確かめられる形で>
   返信の最後の行には、太字や引用などの装飾を付けず、行の先頭から `[<ID>] DONE: <1 行の要約>` とだけ書いて終えてください。
   続けられないときは、同じ形で `[<ID>] BLOCKED: <理由>` と書いてください。
   報告は SendMessage では送らず、この会話の返信として書いてください。
   ```

   既にあるセッションに振るときは、`list_sessions` と `get_session` で cwd・branch・isRunning を確かめる。ユーザーが割り当てていないセッションや、他の作業中のセッションには送らない
4. **完了を待つ。** 子の worktree の cwd を `list_sessions {"linked": true}` で取り、`scripts/wait-markers.sh` をバックグラウンドの Bash で動かす。`list_events` を短い間隔で繰り返し呼ばない

   ```
   ~/.claude/skills/remote-dispatch/scripts/wait-markers.sh <host|local> <子の worktree の cwd> <timeout 秒> <ID>...
   ```

   - host は ssh で使う名前（`~/.ssh/config` の Host。`list_start_targets` の接続名とは別のことがある）。このマシンなら `local`
   - 子ごとに 1 本ずつ動かす
   - 終了コード: 0 = すべて DONE、3 = BLOCKED を含む（手順 6 へ）、2 = タイムアウト、それ以外 = 接続などのエラー
   - タイムアウトしたら、`list_events` と `get_session` で子が許可待ちか、まだ作業中か、印を書かずに止まったかを確かめる。許可待ちは司令塔から許可できないので、どのセッションで何の許可を待っているかをユーザーに伝える。まだ作業中なら、同じコマンドで監視を張り直す
   - Bash の `timeout`（ミリ秒）はスクリプトの timeout より長くする。Bash の上限で止まったときは、同じコマンドで動かし直す
   - 終了コード 255（ssh が切れた）のときは、まず `ssh -o ConnectTimeout=10 <Host> true` で繋がるか確かめる。繋がれば同じコマンドで動かし直す。繋がらなければ、SSH 先のマシンを起こしてもらうようユーザーに頼む。復帰したら `list_events` で子が途中で止まっていないかを確かめ、止まっていれば新しい ID で「中断したところから続けて」と送る
5. **結果を読んで確かめる。** `list_events`（`limit` は小さく）で子の最後の返信を読む。
   - 「DONE」の内容をそのまま信じず、PR・`git log`・CI などの実物を見てから報告する
6. **BLOCKED を閉じる。** BLOCKED は子からの質問なので、返答するまで終わっていない。
   - 理由を確かめ、ユーザーの判断が要るものは、選択肢と推奨を添えてユーザーに聞く
   - 判断が出たら、司令塔が代わりに作業した場合も含めて、結論と次の指示を必ず `SendMessage` で子に送る。手順 2 のとおり新しい ID を振って印の書き方を付け直し、その ID で手順 4 の監視を張り直す
   - 子に送るまでは、ユーザーへの報告でもその件を「対応済み」と書かない
7. **報告する。** ID ごとに「結果・確認したこと・残り」を表にまとめる。完了を報告する前に、手順 8 の点検を必ず行う
8. **止まっている子がいないか点検する。** `list_sessions {"linked": true}` で idle の子を洗い出し、それぞれの最後の返信が DONE か BLOCKED か、印がないかを `list_events` で確かめる。idle は「終わった」という意味ではない。
   - BLOCKED のまま返答していない子や、印を書かずに止まった子がいたら、手順 6 に戻る
   - 子から通知が届いたときと、ユーザーに報告する前に、この点検を行う。定期的に見に行く仕組みは作らない（通知と監視で気づけるため。見落としは返答し忘れで起きる）

## してはいけないこと
- ユーザーが頼んでいない作業を他のセッションに振る
- 子に、権限設定・CLAUDE.md・設定ファイルの変更や、権限の昇格を求める
- 印が出たことだけで「完了」と報告する（中身を読んで確かめる）
- BLOCKED に答えないまま、子を放っておく
