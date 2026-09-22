---
name: status
description: "チームの進捗状況を確認する"
allowed-tools: [Bash, Read]
---

# Multi-Claude Status

チームタスクボードの状態を確認し、進捗を報告する。

## 実行手順

### Step 1: タスクボード確認

```bash
cat .claude-team/taskboard.md
```

### Step 2: worktree状態確認

```bash
wtp list
```

### Step 3: 各ブランチの状態確認

```bash
git branch -v
```

### Step 4: 進捗サマリー作成

以下の形式で報告:

| Member | Status | Progress |
|--------|--------|----------|
| 1 | [status] | [summary] |
| 2 | [status] | [summary] |

- **Completed**: 完了報告済み
- **In Progress**: 作業中（報告なし）
- **Blocked**: ブロック報告あり

## 実行

上記の手順で現在の状態を確認し、PMに報告してください。
