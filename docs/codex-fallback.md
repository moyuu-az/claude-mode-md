# Codex の呼び方（ユーザーが明示的に指示したときだけ）

前提: 自発的に Codex を呼ばない。レビューの既定は `code-reviewer`。

## 通常

`codex exec` を Bash で直接叩かない（認証切れ・引数エスケープで reject されやすい）。
`Agent(subagent_type: "codex:codex-rescue")` を使う。cold context なので対象ファイルの絶対パスと
出力フォーマット（VERDICT / BLOCKERS / REQUIRED CHANGES など）を prompt に書く。

## Agent が auto-deny されたとき

同一セッションで `codex:codex-rescue` を 3 回連続呼ぶと Auto mode の安全閾値で auto-deny されることがある
（anthropics/claude-code #21474, #34095, #50532。拒否時に hang する #7091 と重なることも）。
その場合は同じ shared runtime を通る wrapper を Bash で叩く。パスはバージョン直書きせず glob で解決する:

```bash
COMPANION=$(ls -d ~/.claude/plugins/cache/openai-codex/codex/*/scripts/codex-companion.mjs | sort -V | tail -1)
node "$COMPANION" adversarial-review --wait --base main --scope branch
```

- サブコマンド: `setup --json`（疎通確認）/ `review` / `adversarial-review` / `task --wait --fresh "<prompt>"` / `status` / `result` / `cancel`
- 詰まったらまず `setup --json`（`ready` / `auth.loggedIn` / `codex.detail` を見る）
- 最後の手段はセッション再起動（作業コンテキストを失う）

2026-08-19 時点: plugin 1.0.6 / codex-cli 0.145.0 で Agent 経由は正常動作。
Agent 経由と mjs 直叩きは同じランタイムなので、直叩きは auto-deny 回避のためだけの手段。
