---
name: spawn-team
description: "タスクを分解し、複数のClaude Codeインスタンスをworktree+zellijで並行稼働させる"
argument-hint: <task-description>
allowed-tools: [Bash, Read, Write, WebFetch, Glob, Grep]
---

# Multi-Claude Spawn Team

PMから受けたタスクをLeader Claudeとして分解し、複数のMember Claudeをworktree+zellij環境で並行稼働させる。

## 役割構成

```
PM (User) → Leader Claude (このセッション) → Member Claude (各worktree)
```

## 引数

ユーザーが指定したタスク: $ARGUMENTS

## 実行手順

### Step 1: タスク分析と分解

引数 `$ARGUMENTS` を分析し、並行実行可能なサブタスクに分解する:

1. タスクの全体像を理解
2. 独立して実行可能な単位に分割（2-5個程度）
3. 各サブタスクに以下を定義:
   - 担当範囲（どのファイル/機能を担当）
   - 完了条件
   - 他タスクとの依存関係（あれば）

### Step 2: タスクボードの作成

プロジェクトルートに `.claude-team/` ディレクトリを作成し、タスクボードを初期化:

```bash
mkdir -p .claude-team
```

タスクボードファイル `.claude-team/taskboard.md` を作成:

```markdown
# Claude Team Task Board

## Project
- Task: [元のタスク内容]
- Created: [timestamp]
- Status: in_progress

## Members

| ID | Branch | Tab | Status | Task |
|----|--------|-----|--------|------|
| 1 | feature/xxx | xxx | pending | [サブタスク1] |
| 2 | feature/yyy | yyy | pending | [サブタスク2] |

## Completion Reports
(Members write their completion reports here)
```

### Step 3: 各Memberのworktree作成

各サブタスクに対して:

1. ブランチ名を生成（例: `feature/auth-api`, `feature/auth-ui`）
2. `wtp add -b <branch-name>` でworktree作成
3. worktreeパスを記録

### Step 4: Member向け指示ファイル作成

各worktreeに `.claude-team/my-task.md` を作成:

```markdown
# Your Task

## Assignment
[サブタスク内容]

## Scope
- Files: [担当ファイル/ディレクトリ]
- Do NOT modify: [他Memberの担当範囲]

## Completion Criteria
[完了条件]

## When Done
1. Commit your changes with clear message
2. Append your completion report to `../<main-worktree>/.claude-team/taskboard.md`
3. Format:
   ```
   ### Member [ID] Complete
   - Branch: [branch-name]
   - Summary: [what you did]
   - Files changed: [list]
   - Status: done | blocked | needs-review
   ```
```

### Step 5: zellijタブ起動とClaude Code開始

各Memberに対して:

1. zellijタブを開く:
```bash
zellij action new-tab --name "<short-tab-name>" --cwd <worktree-path>
```

2. Claude Codeを起動:
```bash
zellij action write-chars "claude \".claude-team/my-task.md を読んでタスクを実行してください\""
zellij action write 10
```

### Step 6: 進捗監視

Leaderは定期的にタスクボードを確認:

```bash
cat .claude-team/taskboard.md
```

全Memberの完了報告が揃うまで監視を継続。

### Step 7: マージと統合

全Member完了後:

1. 各ブランチをmainにマージ:
```bash
git checkout main
git merge <branch-1> --no-edit
git merge <branch-2> --no-edit
# ...
```

2. コンフリクトがあれば解決

3. worktreeをクリーンアップ:
```bash
wtp remove --with-branch <branch-1>
wtp remove --with-branch <branch-2>
# ...
```

4. タスクボードを完了状態に更新

### Step 8: PMへの完了報告

以下を含む完了報告を作成:
- 実行したサブタスク一覧
- 各Memberの成果
- マージ結果
- 注意点や今後の課題（あれば）

## エラーハンドリング

### Memberからのブロック報告時
1. タスクボードでブロック内容を確認
2. PMに状況を報告し判断を仰ぐ
3. 必要に応じてタスク再割り当て

### マージコンフリクト時
1. コンフリクト内容をPMに報告
2. 解決方針を確認後、手動解決

## 実行

上記の手順に従って、順番に実行してください。
各ステップの結果をユーザー（PM）に報告しながら進めてください。
