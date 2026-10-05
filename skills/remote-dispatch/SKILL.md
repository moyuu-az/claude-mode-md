---
name: remote-dispatch
description: Use when the user wants this session to act as a dispatcher — handing tasks to other Claude Desktop sessions (especially sessions running on another Mac over SSH or via Remote Control), running them in parallel, and collecting the results. Triggers include「Pro で動かして」「別のマシン（セッション）に振って」「並行して進めて」「司令塔として」「リモートのセッションに指示して」.
---

# 別セッションへの作業の振り分け（司令塔）

このセッションを司令塔にして、他のセッション（別マシンで動く SSH セッションを含む）に作業を振り、完了を待って結果をまとめる。
司令塔は指示・監視・検証だけを行い、作業そのものはしない。

## 前提（実測済み）
- 司令塔は新しいセッションを作れない。作業用のセッションはユーザーにアプリで作ってもらう（環境: SSH > 接続先、worktree を ON、権限モードは auto を推奨）
- 送り先として使えるもの:
  - このアプリのセッション（`list_sessions` に出る。SSH 先で動くものは `get_session` の `isRemote: true`）
  - 別マシンのアプリのセッションで Remote Control が ON のもの（`ListAgents` に出る）
- 作業中のセッションに送ると queued になり、今の作業が終わってから順に実行される
- 受け取った側は「同僚からの依頼」として、自分の権限の範囲で動く。権限の昇格はできない。許可待ちになると止まり、司令塔からは許可できない
- **受け取った側が SendMessage で送り返しても、司令塔には届かない（SSH 先から）。** 結果は会話記録から読む
- `ssh <host> claude -p` は、そのままでは「Not logged in」で動かない（SSH 経由ではキーチェーンを読めない）。使うなら、ホスト側でユーザーが `claude setup-token` を実行し、`CLAUDE_CODE_OAUTH_TOKEN` を設定しておく必要がある

## 手順
1. **送り先を決める。** `list_sessions` と `get_session`（必要なら `ListAgents`）で候補を出し、cwd・branch・isRunning・isRemote をユーザーに見せる。
   - 他の作業をしている（isRunning）セッションや、ユーザーが割り当てていないセッションには送らない
   - 1 タスク = 1 セッション = 1 worktree。同じ worktree に別のタスクを重ねない
   - 足りなければ、必要な数と場所（repo・worktree）を伝えてユーザーに作ってもらう
2. **ID を振る。** 日付を含む一意の ID にする（例: `T1005-1`）。やり直し（BLOCKED 後の再依頼を含む）も新しい ID にする。同じ ID だと前回の印で監視がすぐ終わる
3. **指示を送る。** `send_message`（`session_id` は `local_...`）で、次の雛形を使う

   ```
   [<ID>] 司令塔からの作業依頼です。
   目的: <何を達成するか>
   範囲: <触ってよい場所・ブランチ。push や PR を作るかどうか>
   完了条件: <テストが通る、など確かめられる形で>
   返信の最終行を `[<ID>] DONE: <1 行の要約>` にして終えてください。
   続けられないときは `[<ID>] BLOCKED: <理由>` にしてください。
   報告は SendMessage では送らず、この会話の返信として書いてください。
   ```

4. **完了を待つ。** `scripts/wait-markers.sh` をバックグラウンドの Bash で動かし、終了の通知を待つ。`list_events` を短い間隔で繰り返し呼ばない

   ```
   ~/.claude/skills/remote-dispatch/scripts/wait-markers.sh <host|local> <セッションの cwd> <timeout 秒> <ID>...
   ```

   - host はセッションが動くマシン（SSH の接続先。このマシンなら `local`）。cwd は `get_session` の値
   - 送り先ごとに 1 本ずつ動かしてよい（cwd が違えば監視先も違う）
   - Bash の `timeout`（ミリ秒。既定 30 分、上限 2 時間）はスクリプトの timeout より長くする。Bash の上限で止まったときや、ssh が切れた（終了コード 255）ときは、同じコマンドで動かし直す（止まっている間に出た印も拾う）
5. **結果を集めて確かめる。** `list_events`（`limit` は小さく）で各セッションの最後の返信を読む。
   - 「DONE」の内容をそのまま信じず、必要に応じて `ssh <host> git -C <cwd> log/diff` などで実物を見てから報告する
   - BLOCKED・タイムアウトのものは、理由と、ユーザーに判断してほしいこと（許可・方針など）を分けて伝える
6. **報告する。** ID ごとに「結果・確認したこと・残り」を表にまとめる

## してはいけないこと
- ユーザーが頼んでいない作業を他のセッションに振る
- 受け取った側に、権限設定・CLAUDE.md・設定ファイルの変更や、権限の昇格を求める
- 印が出たことだけで「完了」と報告する（中身を読んで確かめる）
