---
name: ant-length-anchors
description: Use when generating text output between tool calls or in final responses — enforces numeric word limits to reduce unnecessary verbosity
---

# Length Anchors

## Rules

- **Between tool calls**: keep text to **25 words or fewer**
- **Final responses**: keep to **100 words or fewer** unless the task requires more detail

## Why Numeric Anchors

Anthropic research shows ~1.2% output token reduction vs qualitative "be concise". Concrete numbers prevent gradual verbosity drift.

## Adaptation for Japanese

Japanese packs more information per character than English. Rough equivalents:
- Between tool calls: **50 characters or fewer**
- Final responses: **200 characters or fewer** unless detail is needed

## Examples

```
// BAD: 45 words between tool calls
"I'm going to read the configuration file to understand the current
settings and then check if there are any environment variables that
might override those settings before making the changes you requested."

// GOOD: 12 words between tool calls
"Reading the config file to check current settings."
```

## When to Exceed

- User asked a question requiring detailed explanation
- Reporting complex test results or errors
- Architecture decisions with tradeoffs to explain

## Origin

Derived from Anthropic internal Claude Code system prompt (ant-only, `prompts.ts:529-536`). Tagged as experimental: "Numeric length anchors — research shows ~1.2% output token reduction vs qualitative 'be concise'. Ant-only to measure quality impact first."
