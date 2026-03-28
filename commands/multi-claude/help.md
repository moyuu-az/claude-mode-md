---
name: help
description: "multi-claudeコマンドの一覧とヘルプ"
allowed-tools: []
---

# Multi-Claude Command Reference

複数のClaude Codeインスタンスを並行稼働させるコマンド群。

## コマンド一覧

### 🛠️ 実装チーム (worktree使用)

| Command | Description |
|---------|-------------|
| `/multi-claude:spawn-team <task>` | タスクを分解し、worktree+zellijでMemberを起動 |
| `/multi-claude:status` | チームの進捗確認 |
| `/multi-claude:merge-all` | 全ブランチマージ＆クリーンアップ |
| `/multi-claude:abort` | 中止＆全削除 |

### 🔬 調査チーム (worktree不要)

| Command | Description |
|---------|-------------|
| `/multi-claude:super-research <topic>` | 調査トピックを分解し、並列調査を実行 |
| `/multi-claude:research-status` | 調査の進捗確認 |
| `/multi-claude:synthesize` | 各レポートを統合して最終レポート作成 |
| `/multi-claude:research-cleanup` | 調査ファイルのクリーンアップ |

## ワークフロー

### 実装チーム
```
/multi-claude:spawn-team "機能を実装"
    ↓ (各Memberが作業)
/multi-claude:status
    ↓ (完了確認)
/multi-claude:merge-all
```

### 調査チーム
```
/multi-claude:super-research "〇〇について調査"
    ↓ (各Researcherが調査)
/multi-claude:research-status
    ↓ (完了確認)
/multi-claude:synthesize
    ↓
/multi-claude:research-cleanup
```

## 役割構成

```
PM (User)
  └→ Leader Claude (コマンド実行セッション)
       ├→ Member/Researcher #1 (zellijタブ)
       ├→ Member/Researcher #2 (zellijタブ)
       └→ Member/Researcher #3 (zellijタブ)
```
