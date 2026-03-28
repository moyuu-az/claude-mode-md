---
name: research-status
description: "調査の進捗状況を確認する"
allowed-tools: [Bash, Read]
---

# Multi-Claude Research Status

調査ボードとレポートの状態を確認し、進捗を報告する。

## 実行手順

### Step 1: 調査ボード確認

```bash
cat .claude-research/board.md 2>/dev/null || echo "調査ボードが見つかりません"
```

### Step 2: レポート状況確認

```bash
echo "=== Completed Reports ===" && ls -la .claude-research/report-*.md 2>/dev/null || echo "No reports yet"
```

### Step 3: 最終レポート確認

```bash
echo "=== Final Report ===" && ls -la .claude-research/final-report.md 2>/dev/null || echo "Not synthesized yet"
```

### Step 4: 進捗サマリー

以下の形式で報告:

| Researcher | Category | Status |
|------------|----------|--------|
| #1 | [category] | ✅ Complete / 🔄 In Progress / ⏳ Pending |
| #2 | [category] | ✅ Complete / 🔄 In Progress / ⏳ Pending |

**Overall Progress**: X/Y reports complete

**Next Steps**:
- [ ] 残り調査の完了待ち
- [ ] 統合レポート作成 (`/multi-claude:synthesize`)

## 実行

上記の手順で現在の状態を確認し、PMに報告してください。
