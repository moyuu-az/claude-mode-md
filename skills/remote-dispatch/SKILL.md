---
name: remote-dispatch
description: Use when the user wants this session to act as a dispatcher — handing tasks to other Claude Desktop sessions in this app (especially SSH sessions running on another Mac), running them in parallel, and collecting the results. Also use when resuming after this Mac slept, the connection dropped, or the context was summarized while dispatched tasks were outstanding. Triggers include「Pro で動かして」「別のマシン（セッション）に振って」「並行して進めて」「司令塔として」「リモートのセッションに指示して」「振った作業の続き」「スリープから戻った」.
---

# 別セッションへの作業の振り分け（司令塔）

このセッションを司令塔にして、他のセッション（別マシンで動く SSH セッションを含む）に作業を振り、完了を待って結果をまとめる。
司令塔は指示・監視・検証だけを行い、作業そのものはしない。

司令塔のマシンは頻繁にスリープし、接続先のマシンは起動し続ける。振った依頼は司令塔の記憶に置かず、依頼の一覧（`scripts/dispatch.sh`）に記録する。スリープ明け・会話の要約後・新しいセッションでは、依頼の一覧から続きを始める。

## 前提

実機で確かめたことは次のとおり。
- 作業用のセッションは、司令塔が `start_session` で立てられる。SSH 先にも立てられる（2026-10-12 に `target: "ssh"` で確認）
- 立てたセッションは司令塔の linked session になる。`list_sessions {"linked": true}` で cwd・branch・isRunning を見られる
- 子が 1 ターン終えると、アプリが司令塔に知らせる（「finished a turn」の通知や `<side-sessions-event>`）。司令塔が作業中のときやスリープ中は、通知が届かないことがある。通知は補助で、依頼の一覧と `dispatch.sh` を正とする
- 子への追加の指示は `SendMessage`（`to` は子の `local_...` ID）で送る。子が作業中なら queued になり、今の作業が終わってから実行される
- 子は「同僚からの依頼」として、自分の権限の範囲で動く。許可待ちになると止まり、司令塔からは許可できない
- **子が SendMessage で送り返しても、司令塔には届かない（SSH 先から）。** 結果は子の返信を `list_events` で読む
- 接続先では、子のプロセスは SSH の接続ではなく常駐のヘルパー（launchd 配下の `server --serve`）の下で動く。SSH の中継だけが張り直され、子は動き続ける（2026-11-12、中継が 1 時間 41 分前に張り直された時点で、子は 23 時間動いていた）
- 接続先がスリープしたり止まったりすると、子はツール呼び出しの途中で止まり、印を書かないまま idle になる（2026-10-12）
- `ssh <host> claude -p` で直接動かす方法は使わない（SSH 経由ではキーチェーンを読めず「Not logged in」になる）

公式ドキュメント（https://code.claude.com/docs/en/desktop.md 、2026-11-12）で確かめたことは次のとおり。
- 司令塔のマシンがスリープしても、子の作業は続く。"If your computer sleeps, you lose your network, or you quit Desktop, the task goes on until it finishes, needs you, or reaches one of the limits."
- ただし Claude アカウントでサインインしていると、切断のあと子が認証エラーで止まることがある。"the task's sign-in can expire after you disconnect, and the task then stops. How much time is left when you disconnect varies, and it can be only a few minutes." 止まっても作業は残り、メッセージを送れば続けられる。"The work done so far stays on the remote machine, and you can continue with a message when you return."
- アプリが自動で再接続するのは、入力なしでログインできるときだけ。"Desktop reconnects on its own only where it can log in without a prompt, for example with a key that your SSH agent holds."
- 切断中の許可待ちは接続先で待ち続ける。子のプロセスが作り直されると、その許可待ちは失われる。"If Desktop starts a new process instead, you lose the request."
- 動いている子の会話を、接続先で `claude --resume` しない。2 つのプロセスが同じ会話に書き込む

## dispatch.sh

```
~/.claude/skills/remote-dispatch/scripts/dispatch.sh add <ID> <host|local> <子の cwd> <子の session id> [メモ]
~/.claude/skills/remote-dispatch/scripts/dispatch.sh wait <timeout 秒> <ID>...
~/.claude/skills/remote-dispatch/scripts/dispatch.sh status
~/.claude/skills/remote-dispatch/scripts/dispatch.sh close <ID> <確かめたこと・後続の ID>
```

- `add` は依頼を一覧（`~/.claude/remote-dispatch/ledger.tsv`、追記だけ）に記録する。host は ssh で使う名前（`~/.ssh/config` の Host。`list_start_targets` の接続名とは別のことがある）。このマシンなら `local`
- `wait` は、子の会話記録に印が出そろうまで待つ。ssh が切れても張り直し、司令塔のマシンがスリープしていた間に出た印も見つける
- `status` は、閉じていない依頼すべての現状を 1 回調べて表にする
- `close` は依頼を閉じる。閉じるのは、DONE の実物を確かめたあとか、後続の ID を子に送ったあとだけ

`wait` の終了コードは次のとおり。

| コード | 意味 | 次にすること |
| --- | --- | --- |
| 0 | すべて DONE | 手順 5 |
| 3 | BLOCKED を含む | 手順 6 |
| 4 | 子の書き込みが 15 分以上ない | 「止まった子の扱い」 |
| 2 | タイムアウト | 「止まった子の扱い」 |
| 255 | 接続できないまま時間切れ | `ssh -o BatchMode=yes -o ConnectTimeout=10 <Host> true` で確かめる。つながらなければ、接続先のマシンと回線をユーザーに確かめてもらう。つながれば同じコマンドで待ち直す |
| 64・65・66 | 引数の誤り・依頼の一覧と合わない・接続先に会話記録がない | メッセージのとおりに直す |

## 手順
1. **立てる場所を決める。** `list_start_targets` で SSH の接続名（`host`）と、接続先の最近のフォルダを確かめる。接続名は推測しない。
   - 1 タスク = 1 セッション = 1 worktree。同じ worktree に別のタスクを重ねない
   - 接続先には、`ssh -o BatchMode=yes -o ConnectTimeout=10 <ssh の Host> true` でつながることを先に確かめる。BatchMode で通らない接続は、司令塔のマシンがスリープから戻るたびに、アプリが自動で再接続できない。鍵を SSH agent に入れるようユーザーに頼む
   - repo の作業ツリーは、別の作業のブランチに切り替わっていることがある。立てる前に `ssh <ssh の Host> git -C <repo> branch --show-current`（このマシンなら `ssh <ssh の Host>` を付けない）で確かめ、`source_branch` に `main` などの起点を明示する
2. **ID を振る。** 日付を含む一意の ID にする（例: `T1005-1`）。追加の指示・やり直し・BLOCKED への返答も、毎回新しい ID にする。同じ ID は `add` が拒否する。送る文の先頭には `[<新しい ID>]` を付け、雛形の最後の 3 行（印の書き方と、SendMessage で送らないこと）も新しい ID で付け直す。付けないと、子は前の ID で印を書き、新しい ID の `wait` はタイムアウトまで終わらない
3. **立てて指示し、依頼の一覧に記録する。** `start_session` を次の値で呼ぶ。
   - `initiation: "user_asked"`、`context: "fresh"`、`target: "ssh"`、`host`（手順 1 の接続名）、`cwd`（接続先の repo の絶対パス）、`use_worktree: true`、`source_branch`、`branch_name`
   - このマシンに立てるときは `target` と `host` を省き、`cwd` にこのマシンの repo を渡す
   - `background` には全体の目的・他の子の担当・共有する制約（CPU や全体テストの順番など）を書く
   - `prompt` は次の雛形にする

   ```
   [<ID>] 司令塔からの作業依頼です。
   目的: <何を達成するか>
   範囲: <触ってよい場所・ブランチ。push や PR を作るかどうか>
   完了条件: <テストが通る、など確かめられる形で>
   作業は区切りごとにコミットしてください。途中で止まっても、コミットから続きを始められるようにするためです。
   返信の最後の行には、太字や引用などの装飾を付けず、行の先頭から `[<ID>] DONE: <1 行の要約>` とだけ書いて終えてください。
   続けられないときは、同じ形で `[<ID>] BLOCKED: <理由>` と書いてください。
   報告は SendMessage では送らず、この会話の返信として書いてください。
   ```

   - 立てたらすぐ、`list_sessions {"linked": true}` で子の worktree の cwd と session id を取り、`dispatch.sh add` で記録する。`wait` より先に記録する。記録のない ID は `wait` が拒否する
   - 既にあるセッションに振るときは、`list_sessions` と `get_session` で cwd・branch・isRunning を確かめる。ユーザーが割り当てていないセッションや、他の作業中のセッションには送らない。`SendMessage` で送ったら、同じように `add` で記録する
4. **完了を待つ。** `dispatch.sh wait <timeout 秒> <ID>...` をバックグラウンドの Bash で動かす。`list_events` を短い間隔で繰り返し呼ばない
   - 子ごとに 1 本ずつ動かす。別の子の ID をまとめると拒否される
   - Bash の `timeout`（ミリ秒）は `wait` の timeout より長くする。Bash の上限で止まったときは、同じコマンドで動かし直す。何度動かし直しても、依頼の時刻までさかのぼって印を探すので取りこぼさない
5. **結果を読んで確かめる。** `list_events`（`limit` は小さく）で子の最後の返信を読む。
   - 「DONE」の内容をそのまま信じず、PR・`git log`・CI などの実物を見る
   - 確かめたら `dispatch.sh close <ID> <確かめたこと>` で閉じる。確かめる前に閉じない
6. **BLOCKED を閉じる。** BLOCKED は子からの質問なので、返答するまで終わっていない。
   - 理由を確かめ、ユーザーの判断が要るものは、選択肢と推奨を添えてユーザーに聞く
   - 判断が出たら、司令塔が代わりに作業した場合も含めて、結論と次の指示を必ず `SendMessage` で子に送る。手順 2 のとおり新しい ID を振って印の書き方を付け直し、新しい ID を `add` で記録して `wait` を動かす
   - 子に送ったあとで、古い ID を `dispatch.sh close <古い ID> <新しい ID> で返答` で閉じる。子に送るまでは閉じず、ユーザーへの報告でもその件を「対応済み」と書かない
7. **報告する。** ID ごとに「結果・確認したこと・残り」を表にまとめる。完了を報告する前に `dispatch.sh status` を実行する。「未完了の依頼はありません」と出るまでは、残っている ID と状態を報告に書く

## 復帰したとき

スリープ明け、接続が切れたあと、会話の要約後、新しいセッションで続きを頼まれたとき、子から通知が届いたときは、最初に `dispatch.sh status` を実行する。前に動かしていた `wait` は止まっていることがあるので、当てにしない。状態ごとに次のように進める。

| 状態 | すること |
| --- | --- |
| DONE | 手順 5（実物を確かめて close） |
| BLOCKED | 手順 6 |
| PENDING | 子は作業中。`wait` を動かし直す |
| PENDING（15 分以上書き込みなし） | 「止まった子の扱い」 |
| UNREACHABLE | 接続先につながらない。少し待って `status` をやり直す。続くなら、接続先のマシンと回線をユーザーに確かめてもらう |
| ERROR(66) | 接続先に会話記録がない。`add` に渡した host を確かめる |

依頼の一覧にあるのは `add` で記録した依頼だけである。`list_sessions {"linked": true}` も見て、依頼の一覧にない子（`add` の前に司令塔が止まった場合）が残っていないかを確かめる。残っていれば、`list_events` で最初の依頼の ID と子の最後の返信を読み、`add` で記録してから同じように扱う。

## 止まった子の扱い

`wait` が 4 か 2 で終わったとき、または `status` に「書き込みなし」と出たときは、`list_events` と `get_session` で子の最後の様子を読み、次のどれかを決める。

- **許可待ち。** 司令塔からは許可できない。どのセッションで何の許可を待っているかをユーザーに伝える。切断のあとで子のプロセスが作り直されていると、許可待ちそのものが失われている。そのときは次の「印を書かずに止まった」として扱う
- **印を書かずに止まった**（認証エラー、接続先の再起動、ターンの途中での中断）。新しい ID を振り、「中断したところから続けてください。まず `git status` と `git log` で、どこまで終わっているかを確かめてください」と雛形の最後の 3 行を付けて `SendMessage` で送る。新しい ID を `add` し、古い ID を `close <古い ID> <新しい ID> で再開` で閉じてから、`wait` を動かす。接続先で `claude --resume` はしない
- **長い処理の途中**（15 分を超えるビルドやテスト）。`DISPATCH_STALL=<秒>` を付けて `wait` を動かし直す（例: `DISPATCH_STALL=3600`。0 で無効）

認証エラーで止まる子が続くときは、司令塔のマシンが切断している間に子のサインインが切れている。公式ドキュメントは、切断中も動かし続けたい作業には、司令塔のマシンを起こしたままにするか、クラウドのセッションを使うよう勧めている。どちらにするかはユーザーに聞く。

## してはいけないこと
- ユーザーが頼んでいない作業を他のセッションに振る
- 子に、権限設定・CLAUDE.md・設定ファイルの変更や、権限の昇格を求める
- 印が出たことだけで「完了」と報告する（中身を読んで確かめる）
- BLOCKED に答えないまま、子を放っておく
- 実物を確かめる前、または後続の ID を子に送る前に `close` する
- 依頼の一覧のファイルを手で書き換える（追記だけで成り立っている）
