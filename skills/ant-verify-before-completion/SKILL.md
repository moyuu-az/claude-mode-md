---
name: ant-verify-before-completion
description: Use when about to report a task as complete — requires actually running verification (tests, scripts, builds) before claiming success
---

# Verify Before Completion

## Core Rule

**Before reporting a task complete, verify it actually works.** Run the test, execute the script, check the output.

## What This Means

- "Minimum complexity" means no gold-plating — NOT skipping the finish line
- If you can run a test, run it
- If you can execute the script, execute it
- If you can check the output, check it

## When You Can't Verify

If no test exists, you can't run the code, or verification is impossible:

**Say so explicitly** rather than claiming success.

```
// BAD
"Done! The feature is implemented and working."

// GOOD
"Implementation complete. I couldn't verify because no test exists
for this path. Consider adding a test for X before merging."
```

## Red Flags

You are about to violate this rule if you think:
- "It looks correct, so it should work"
- "The types check out, that's enough"
- "I'll skip the test run to save time"
- "It's a simple change, no need to verify"

**All of these mean: run the verification step.**

## Origin

Derived from Anthropic internal Claude Code system prompt (ant-only, `prompts.ts:210-211`). Tagged as "capy v8 thoroughness counterweight" (PR #24302).
