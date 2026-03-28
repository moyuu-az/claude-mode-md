---
name: super-research
description: "調査タスクを分解し、複数のClaude Codeインスタンスで並列調査を実行"
argument-hint: <research-topic>
allowed-tools: [Bash, Read, Write, WebFetch, WebSearch, Glob, Grep]
---

# Multi-Claude Super Research

調査トピックを複数の観点に分解し、並列でClaude Codeインスタンスを起動して調査を実行。
最終的にLeaderが全調査結果を統合してレポートを作成する。

## 役割構成

```
PM (User) → Leader Claude (このセッション) → Researcher Claude (各zellijタブ)
```

## 調査カテゴリ

| Category | Focus | Tools |
|----------|-------|-------|
| 🔍 Code | コードベース調査 | Grep, Glob, Read |
| 📚 Docs | ドキュメント調査 | Read, Context7 |
| 📋 Spec | 仕様書・設計書調査 | Read, Grep |
| 🌐 Web | ネット調査 | WebSearch, Tavily |
| 🏗️ Arch | アーキテクチャ調査 | Serena, Read |

## 引数

調査トピック: $ARGUMENTS

## 実行手順

### Step 1: 調査計画の策定

引数 `$ARGUMENTS` を分析し、必要な調査カテゴリを特定:

1. 調査トピックの理解
2. 必要な調査観点を決定（2-5個）
3. 各観点に対して:
   - 調査目的
   - 調査範囲
   - 期待する成果物
   - 使用すべきツール

### Step 2: 調査ボードの作成

プロジェクトルート（またはホームディレクトリ）に調査ディレクトリを作成:

```bash
mkdir -p .claude-research
```

調査ボード `.claude-research/board.md` を作成:

```markdown
# Super Research Board

## Topic
$ARGUMENTS

## Created
[timestamp]

## Status
in_progress

## Researchers

| ID | Category | Tab | Status | Focus |
|----|----------|-----|--------|-------|
| 1 | 🔍 Code | code | pending | [調査内容] |
| 2 | 📚 Docs | docs | pending | [調査内容] |
| 3 | 🌐 Web | web | pending | [調査内容] |

## Findings Summary
(Leader will synthesize here after all complete)
```

### Step 3: 各Researcher向け指示ファイル作成

各Researcherの指示を `.claude-research/task-{id}.md` に作成:

```markdown
# Research Task #{id}

## Category
[🔍 Code / 📚 Docs / 📋 Spec / 🌐 Web / 🏗️ Arch]

## Focus
[具体的な調査内容]

## Scope
[調査範囲の指定]

## Expected Output
[期待する成果物]

## Recommended Tools
[使用すべきツール]

## Output File
Write your findings to: `.claude-research/report-{id}.md`

## Report Format
```markdown
# Research Report #{id}: [Category]

## Summary
[3-5行の要約]

## Key Findings
- [発見1]
- [発見2]
- ...

## Details
[詳細な調査結果]

## Sources/References
- [参照元1]
- [参照元2]

## Open Questions
[未解決の疑問点]
```

## When Done
1. Save your report to `.claude-research/report-{id}.md`
2. Your task is complete after saving the report
```

### Step 4: zellijタブ起動とResearcher開始

各Researcherに対して:

1. zellijタブを開く:
```bash
zellij action new-tab --name "<category-short>" --cwd <current-dir>
```

タブ名の例:
- 🔍 Code → `code`
- 📚 Docs → `docs`
- 📋 Spec → `spec`
- 🌐 Web → `web`
- 🏗️ Arch → `arch`

2. Claude Codeを起動:
```bash
zellij action write-chars "claude \".claude-research/task-{id}.md を読んで調査を実行し、レポートを作成してください\""
zellij action write 10
```

### Step 5: 進捗監視

Leaderは定期的にレポートファイルの存在を確認:

```bash
ls -la .claude-research/report-*.md
```

全レポートが揃うまで監視。

### Step 6: 調査結果の統合

全Researcher完了後:

1. 各レポートを読み込み
2. 重複・矛盾の確認
3. 知見の統合
4. 総合レポートを作成

統合レポート `.claude-research/final-report.md`:

```markdown
# Research Report: [Topic]

## Executive Summary
[全体の要約]

## Research Methodology
- Researchers: [人数]
- Categories: [調査カテゴリ]
- Duration: [所要時間]

## Consolidated Findings

### [カテゴリ1]
[統合された知見]

### [カテゴリ2]
[統合された知見]

## Cross-Category Insights
[複数カテゴリにまたがる発見]

## Conclusions
[結論]

## Recommendations
[推奨事項]

## Appendix: Individual Reports
- Report #1: [リンクまたは要約]
- Report #2: [リンクまたは要約]
```

### Step 7: PMへの報告

最終レポートの内容をPMに報告:
- 調査トピック
- 実施した調査カテゴリ
- 主要な発見
- 結論と推奨事項

## 調査カテゴリ詳細

### 🔍 Code Investigation
- 対象: ソースコード、実装詳細
- ツール: Grep, Glob, Read, Serena
- 出力: 実装パターン、依存関係、技術的制約

### 📚 Documentation Research
- 対象: README、Wiki、コメント、外部ドキュメント
- ツール: Read, Context7, WebFetch
- 出力: 設計意図、使用方法、ベストプラクティス

### 📋 Specification Research
- 対象: 仕様書、設計書、ADR、RFC
- ツール: Read, Grep
- 出力: 要件、制約、設計決定の根拠

### 🌐 Web Research
- 対象: 公式ドキュメント、ブログ、Stack Overflow
- ツール: WebSearch, Tavily, WebFetch
- 出力: 外部知識、業界標準、類似事例

### 🏗️ Architecture Research
- 対象: システム構造、モジュール関係
- ツール: Serena, Read, Grep
- 出力: アーキテクチャ図、依存関係、設計パターン

## 実行

上記の手順に従って、順番に実行してください。
各ステップの結果をPMに報告しながら進めてください。
