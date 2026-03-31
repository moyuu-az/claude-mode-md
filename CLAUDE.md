# Global Instructions

## Language
日本語で応答する。技術用語は英語のまま使用。

## Preferred Tech Stack
- **Frontend**: React + TypeScript + Next.js (App Router) + Tailwind CSS
- **Backend**: Node.js + TypeScript + Express (or Next.js API Routes)
- **DB**: PostgreSQL + Prisma/Drizzle, Redis (cache)
- **Infra**: Docker, GitHub Actions, pino (logging)

プロジェクトの既存スタックを常に優先すること。上記はデフォルト参照用。

## Workflow
1. 既存コードを読んでから修正する（推測で変更しない）
2. 3ステップ以上のタスクは TaskCreate で TODO を作成してから実装
3. 並列実行可能な操作は並列で（Read, Glob 等のバッチ呼び出し）
4. 実装完了後にテスト/lint を実行して検証
5. feature ブランチで作業、main には直接コミットしない

## Code Quality
- `any` 禁止、明示的な型定義
- 入力バリデーション必須（Zod）
- エラーハンドリングを省略しない
- 不要な抽象化・過剰設計をしない（YAGNI）
- 要求されたスコープだけ実装する（勝手に機能追加しない）
- TODO / stub / mock 実装を残さない（始めたら完了させる）

## Git
- `git status` と `git branch` をセッション開始時に確認
- feature ブランチで作業
- コミット前に `git diff` で変更確認
- Conventional Commits: `feat:`, `fix:`, `docs:`, `refactor:`

## Debugging
1. エラーメッセージとスタックトレースを最初に読む
2. データフローを追跡して根本原因を特定
3. 症状ではなく原因を修正する
4. テストをスキップ/無効化してビルドを通さない

## Obsidian ドキュメント化

**Vault**: `Code-Notizbuch` | **Skill**: `~/.claude/skills/obsidian-doc/SKILL.md`

作業完了時に Obsidian vault にドキュメントを書き出すこと。

**階層構造**: `{Type}/{project}/{YYYY-MM}/YYYY-MM-DD-title.md`
- 例: `Sessions/claude-code-config/2026-03/2026-03-28-skill-creation.md`

**プロジェクト MOC**: 新規プロジェクト初回時に `Index/Projects/{project}.md` を作成。

制約: YAML frontmatter 必須 (type, date, project, tags, status)、`[[wikilink]]` でクロスリファレンス、`YYYY-MM-DD-kebab-case-title.md` 命名規則。詳細はスキル参照。

## Available Skills (on-demand)
以下のスキルは必要時に呼び出して使用する（常時ロードしない）:
- `/sc:brainstorm` - 要件発見・ブレインストーミング
- `/sc:research` - 深掘り調査
- `/sc:business-panel` - ビジネス分析パネル
- `/sc:analyze` - コード分析
- `/sc:test` - テスト実行
- `/sc:build` - ビルド実行
