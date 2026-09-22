---
name: merge-all
description: "全Memberのブランチをマージしてworktreeをクリーンアップ"
allowed-tools: [Bash, Read]
---

# Multi-Claude Merge All

全Memberの作業ブランチをmainにマージし、worktreeをクリーンアップする。

## 前提条件

- 全Memberが完了報告済み
- タスクボードで全員のステータスが確認済み

## 実行手順

### Step 1: タスクボード確認

```bash
cat .claude-team/taskboard.md
```

全Memberの完了報告があることを確認。

### Step 2: mainブランチに移動

```bash
git checkout main
git pull origin main
```

### Step 3: 各ブランチをマージ

タスクボードに記載された各ブランチを順番にマージ:

```bash
git merge <branch-name> --no-edit
```

コンフリクト発生時はPMに報告して判断を仰ぐ。

### Step 4: worktreeクリーンアップ

各worktreeを削除:

```bash
wtp remove --with-branch <branch-name>
```

### Step 5: タスクボード更新

`.claude-team/taskboard.md` のStatusを `completed` に更新。

### Step 6: 完了報告

PMに以下を報告:
- マージしたブランチ一覧
- 最終的な変更サマリー
- 削除したworktree一覧

## 実行

上記の手順で実行してください。
コンフリクトやエラーが発生した場合は必ずPMに報告してください。
