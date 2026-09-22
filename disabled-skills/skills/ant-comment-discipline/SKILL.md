---
name: ant-comment-discipline
description: Use when writing or modifying code — enforces minimal, WHY-only commenting to prevent over-commenting and comment rot
---

# Comment Discipline

## Core Rule

**Default to writing no comments.** Only add one when the WHY is non-obvious.

## When to Comment

Add a comment ONLY when ALL of these are true:
- The WHY is non-obvious (hidden constraint, subtle invariant, workaround for a specific bug, behavior that would surprise a reader)
- Removing the comment would confuse a future reader

## What NOT to Comment

- **WHAT the code does** — well-named identifiers already do that
- **Current task references** — "used by X", "added for the Y flow", "handles the case from issue #123" belong in the PR description and rot as the codebase evolves
- **Caller context** — "called by FooService" becomes wrong after refactoring

## Existing Comments

Don't remove existing comments unless you're removing the code they describe or you know they're wrong. A comment that looks pointless may encode a constraint or lesson from a past bug not visible in the current diff.

## Examples

```typescript
// BAD: explains WHAT
// Loop through users and filter active ones
const active = users.filter(u => u.isActive);

// BAD: references task
// Added for the auth refactor (PROJ-123)
const token = await refreshToken();

// GOOD: explains WHY (hidden constraint)
// OAuth tokens expire 5min before their stated expiry — refresh early to avoid race
const token = await refreshToken({ bufferMs: 300_000 });
```

## Origin

Derived from Anthropic internal Claude Code system prompt (ant-only, `prompts.ts:204-213`). Added to counter Capybara v8's over-commenting tendency.
