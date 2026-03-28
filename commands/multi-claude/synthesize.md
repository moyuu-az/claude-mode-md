---
name: synthesize
description: "各Researcherのレポートを統合して最終レポートを作成"
allowed-tools: [Bash, Read, Write]
---

# Multi-Claude Synthesize

各Researcherが作成したレポートを統合し、最終レポートを作成する。

## 前提条件

- `.claude-research/` ディレクトリが存在
- 各Researcherのレポート (`report-*.md`) が作成済み

## 実行手順

### Step 1: レポート確認

```bash
ls -la .claude-research/report-*.md
```

### Step 2: 調査ボード確認

```bash
cat .claude-research/board.md
```

### Step 3: 各レポートの読み込み

全ての `report-*.md` ファイルを読み込み、内容を把握。

### Step 4: 統合分析

以下の観点で分析:

1. **共通テーマ**: 複数レポートで言及されている事項
2. **矛盾点**: レポート間で異なる見解
3. **補完関係**: 互いに補い合う情報
4. **未解決事項**: 残された疑問

### Step 5: 最終レポート作成

`.claude-research/final-report.md` を作成:

```markdown
# Research Report: [Topic]

## Executive Summary
[3-5行の総括]

## Research Overview
- **Topic**: [調査トピック]
- **Researchers**: [人数] parallel instances
- **Categories**: [調査カテゴリ一覧]

## Key Findings

### Finding 1: [タイトル]
[詳細]
- Source: Report #X

### Finding 2: [タイトル]
[詳細]
- Source: Report #X, #Y

## Cross-Category Insights
[複数カテゴリにまたがる発見・パターン]

## Contradictions & Resolutions
[矛盾点とその解釈]

## Open Questions
[未解決の疑問]

## Conclusions
[結論]

## Recommendations
[推奨事項・次のアクション]

---

## Appendix: Individual Reports

### Report #1: [Category]
[要約]

### Report #2: [Category]
[要約]
```

### Step 6: PMへの報告

最終レポートの内容をPMに報告。

## 実行

上記の手順で統合レポートを作成してください。
