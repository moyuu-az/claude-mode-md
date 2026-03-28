---
paths:
  - "**/*.ts"
  - "**/*.tsx"
---

# TypeScript Conventions

- Strict mode 必須、`any` 禁止（`unknown` + type guard を使う）
- 関数は明示的な戻り値型を持つこと
- `interface` > `type` (拡張可能な場合)
- 入力バリデーションは Zod を使用
- 命名: camelCase(変数/関数), PascalCase(コンポーネント/型), UPPER_SNAKE(定数)
- ファイル名: kebab-case (例: `user-profile.service.ts`)
- DB カラム: snake_case (例: `created_at`)
- 2スペースインデント、シングルクォート、セミコロン必須、末尾カンマ
