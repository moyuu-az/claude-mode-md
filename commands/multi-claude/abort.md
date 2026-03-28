---
name: abort
description: "チーム作業を中止し、全worktreeをクリーンアップ"
allowed-tools: [Bash, Read]
---

# Multi-Claude Abort

チーム作業を中止し、全worktreeとブランチをクリーンアップする。

## 警告

このコマンドは全Memberの作業を破棄します。
未コミットの変更は失われます。

## 実行手順

### Step 1: 確認

PMに中止の確認を取る:
「全Memberの作業を中止し、worktreeを削除しますか？未コミットの変更は失われます。」

### Step 2: worktree一覧取得

```bash
wtp list
```

### Step 3: タスクボード確認

```bash
cat .claude-team/taskboard.md
```

チーム用ブランチを特定。

### Step 4: 各worktree削除

```bash
wtp remove --force --with-branch --force-branch <branch-name>
```

### Step 5: クリーンアップ

```bash
rm -rf .claude-team/
git checkout main
```

### Step 6: 報告

PMに中止完了を報告:
- 削除したworktree/ブランチ一覧
- 現在の状態

## 実行

PMの確認を得てから実行してください。
