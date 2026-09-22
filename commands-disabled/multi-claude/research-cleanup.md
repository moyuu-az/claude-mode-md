---
name: research-cleanup
description: "調査ファイルをクリーンアップ"
allowed-tools: [Bash, Read]
---

# Multi-Claude Research Cleanup

調査完了後、`.claude-research/` ディレクトリをクリーンアップする。

## 実行手順

### Step 1: 最終レポート確認

```bash
cat .claude-research/final-report.md 2>/dev/null
```

最終レポートが存在し、内容が適切か確認。

### Step 2: PM確認

「最終レポートを保存しましたか？調査ファイルを削除しますか？」

### Step 3: クリーンアップ

```bash
rm -rf .claude-research/
```

### Step 4: 完了報告

クリーンアップ完了をPMに報告。

## 実行

PMの確認を得てから実行してください。
