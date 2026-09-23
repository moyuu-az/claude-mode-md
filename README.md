# claude-mode-md

[Claude Code](https://claude.com/claude-code) の個人設定（`~/.claude`）です。
グローバルな指示・サブエージェント・スキル・ルールを管理しています。

## 構成

| パス | 内容 |
| --- | --- |
| `CLAUDE.md` | 全プロジェクト共通の指示（設計方針・レビュー運用・Git 規約など） |
| `agents/` | サブエージェント。`code-reviewer`（通常のレビュー）と `deep-reviewer`（難しいレビューのエスカレーション先） |
| `skills/` | 自作・導入済みのスキル（例: 完了前の検証、指摘の積極性、シーケンス図による検証、worktree の整理、graphify） |
| `rules/` | 言語別・横断的なルール（`security.md` / `typescript.md`） |
| `hooks/` | hook スクリプト |
| `docs/` | 運用メモ（レビュー運用の経緯、Codex への切り替え手順） |
| `statusline*.sh` / `runcat-statusline.py` / `notify.sh` | ステータスライン表示と通知のスクリプト |
| `agents-disabled/` `commands-disabled/` `disabled-skills/` | 使わなくなった定義の保管場所（Claude Code からは読み込まれない） |
| ルート直下の `MODE_*.md` `MCP_*.md` `FLAGS.md` など | 以前導入していた SuperClaude の名残。現在の `CLAUDE.md` からは参照していない |

## 追跡していないもの

`~/.claude` には Claude Code が実行時データ（会話履歴・セッション・キャッシュ・認証情報）を次々に書き込みます。
そのため `.gitignore` は allowlist 方式（`/*` ですべて除外し、手で管理するものだけ `!` で許可）にしています。

次のファイルは意図的に追跡していません。

- `settings.json` / `settings.local.json`: permissions やプラグイン設定に、業務案件のパスやインフラ名が溜まるため
- `plugins/`: インストール状態はマシン固有のため
- `history.jsonl`、`projects/`、`file-history/` など: 会話履歴そのもの

新しいファイルを追跡したい場合は、`.gitignore` に `!/<path>` を追加してください。

## 使い方

`~/.claude` はすでに Claude Code が使っているディレクトリなので、直接 clone せず、既存のディレクトリに取り込みます。

```sh
cd ~/.claude
git init
git remote add origin git@github.com:moyuu-az/claude-mode-md.git
git fetch origin
git checkout -f -b main --track origin/main   # 同名の既存ファイルは上書きされる
```

一部だけ使いたい場合は、必要なファイル（`agents/*.md` や `skills/<name>/`）を `~/.claude` の同じ場所にコピーしてください。

`skills/` のうち `agent-browser` などは `~/.agents/skills` への symlink なので、この repo には含まれていません。
