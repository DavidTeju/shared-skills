---
name: nextjs-prisma-client-component-import
description: |
  Fix "the chunking context does not support external modules (request: node:module)" error in Next.js
  with Prisma. Use when: (1) Next.js build fails with node:module error, (2) Turbopack shows "chunking
  context does not support external modules", (3) Client component imports types from @/generated/prisma/client
  or @prisma/client/runtime/client, (4) Error trace shows "Client Component Browser" importing Prisma types.
  Root cause: Prisma client includes Node.js-specific code that can't be bundled for the browser.
author: Claude Code
user-invocable: false
---

# Next.js Prisma Client Component Import Error

## Problem

When importing Prisma types in Next.js client components (`'use client'`), the build fails with a cryptic error that doesn't clearly indicate Prisma as the culprit:

```
Error: Turbopack build failed with 1 errors:
./src/app/(dashboard)/budget/page.tsx
the chunking context (unknown) does not support external modules (request: node:module)
```

## Context / Trigger Conditions

- Next.js 14+ with Turbopack (or webpack)
- Build fails with `node:module` or similar Node.js built-in module errors
- Error trace mentions "Client Component Browser"
- A `'use client'` component imports from:
  - `@/generated/prisma/client`
  - `@prisma/client`
  - `@prisma/client/runtime/client`
- Often happens with shared type files that import Prisma types and are used by both server and client code

## Root Cause

Prisma's generated client includes Node.js-specific code (file system access, native bindings, etc.). When you import ANYTHING from the Prisma client package—even just TypeScript types—the bundler may include the entire module, pulling in Node.js code that can't run in the browser.

This commonly happens when:
1. A types file imports `Decimal` from `@prisma/client/runtime/client`
2. A types file imports model types directly from `@/generated/prisma/client`
3. These type files are then imported by client components

## Solution

### Option 1: Import Enums Separately (Recommended)

Prisma generates a separate enums file that's browser-safe:

```typescript
// BAD - pulls in Node.js code
import type { Tier, BudgetType } from '@/generated/prisma/client';
import type { Decimal } from '@prisma/client/runtime/client';

// GOOD - browser-safe
import type { Tier, BudgetType } from '@/generated/prisma/enums';
```

### Option 2: Declare Types Locally for Client Code

For complex types, declare minimal versions locally:

```typescript
// src/features/budget/types/index.ts (used by client components)
import type { Tier, BudgetType } from '@/generated/prisma/enums';

// Use number instead of Prisma Decimal for client-safe types
type Decimal = number;

// Declare minimal types needed (avoid importing full Prisma client)
interface Budget {
  id: string;
  name: string;
  type: BudgetType;
  year: number;
  month: number | null;
  // ... only the fields you need
}
```

### Option 3: Separate Server and Client Type Files

Create two type files:
- `types/server.ts` - imports from Prisma client (used only in server code)
- `types/client.ts` - browser-safe types (used in client components)

## Verification

After fixing, run:
```bash
npm run build
```

The build should complete without the `node:module` error.

## Example

**Before (broken):**
```typescript
// src/features/budget/types/index.ts
import type { Tier, Budget, Category } from '@/generated/prisma/client';
import type { Decimal } from '@prisma/client/runtime/client';  // CAUSES ERROR!

export interface BudgetItem {
  amount: Decimal;  // Uses Prisma Decimal
  // ...
}
```

**After (fixed):**
```typescript
// src/features/budget/types/index.ts
import type { Tier, BudgetType } from '@/generated/prisma/enums';

// Client-safe: use number instead of Prisma Decimal
type Decimal = number;

// Declare minimal types locally
interface Budget {
  id: string;
  name: string;
  type: BudgetType;
  year: number;
  month: number | null;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export interface BudgetItem {
  amount: Decimal;  // Now just 'number'
  // ...
}
```

## Notes

- This issue affects both Turbopack and webpack bundlers
- The error message is misleading—it says `node:module` but the actual fix is about Prisma imports
- Prisma's `enums.ts` file is auto-generated and browser-safe
- If you need the actual `Decimal` type for precision, keep that logic server-side and convert to `number` before sending to client
- This commonly manifests when creating shared type files that are imported by both tRPC routers (server) and React components (client)

## References

- [Prisma Client Browser Docs](https://www.prisma.io/docs/orm/prisma-client/setup-and-configuration/browser-compatibility)
- [Next.js Client Components](https://nextjs.org/docs/app/building-your-application/rendering/client-components)
