---
name: worktree-cleanup
description: Use when the user asks to clean up / 整理 git worktrees or stale branches. Inventories all worktrees (including manually created ones), checks PR state via gh (squash-merge safe), and removes only merged ones after user approval.
---

# Worktree の棚卸しと削除

1. `git worktree list` と `git branch -vv` で全体像を把握
2. 各 worktree で `git status --porcelain` を確認し、未コミット変更の有無を洗い出す
3. **squash merge では `git branch --merged` / `merge-base --is-ancestor` は機能しない。**
   `gh pr list --head <branch> --state all` で MERGED / OPEN / なし を確認する
4. 削除対象 = PR が MERGED、または全コミットが他の生きているブランチに取り込み済みのもの。
   OPEN PR・PR なし・判断不能なものは残す
5. 削除計画（消すもの / 残すもの）を提示し、**ユーザー承認を得てから** `git worktree remove` → `git branch -D`
   - squash merge 済みは `-d` が通らないので `-D`。GitHub の PR から復元可能な旨を添える
   - **今のセッションが中にいる worktree だけは `ExitWorktree({ action: "remove" })`**（cwd が宙に浮くのを避ける）
6. 仕上げに `git fetch --prune` と `git worktree prune`

未追跡ファイルだけが残る worktree は中身を確認し、生成物ゴミなら `--force` 削除で可。
実質的な変更があれば必ずユーザーに報告して指示を仰ぐ。
