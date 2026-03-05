---
name: nextjs-client-server-boundary-dns-error
description: |
  Fix "Module not found: Can't resolve 'dns'" (or 'fs', 'net', 'tls') errors in Next.js with Prisma.
  Use when: (1) Build fails with "Can't resolve 'dns'" from pg/connection-parameters.js,
  (2) Error trace shows "[Client Component Browser]" importing server modules,
  (3) Using Prisma with @prisma/adapter-pg and getting Node.js module errors,
  (4) Barrel exports cause unexpected server code in client bundles.
  Covers: barrel export patterns, Prisma enum imports, direct component imports, serverExternalPackages.
author: Claude Code
user-invocable: false
---

# Next.js Client/Server Boundary: DNS Module Error

## Problem

Next.js build fails with errors like:
```
Module not found: Can't resolve 'dns'
./node_modules/pg/lib/connection-parameters.js

Import trace:
  Client Component Browser:
    ./node_modules/@prisma/adapter-pg/dist/index.mjs [Client Component Browser]
    ./src/lib/db/client.ts [Client Component Browser]
    ...
```

Similar errors occur for `fs`, `net`, `tls`, and other Node.js-only modules.

## Context / Trigger Conditions

This error occurs when server-only code (like Prisma with pg adapter) is accidentally bundled into client components. The error message is **misleading**—it says "dns not found" but the actual problem is a client/server boundary violation.

**Common triggers:**

1. **Barrel exports that include server modules:**
   ```typescript
   // features/budget/index.ts - PROBLEMATIC
   export * from './services/alerts';  // imports prisma
   export * from './components';        // client components

   // Client component imports from barrel
   import { BudgetChart } from '@/features/budget';  // Pulls in ALL exports!
   ```

2. **Importing Prisma enums in client components:**
   ```typescript
   // WRONG - pulls in full Prisma runtime
   import { BudgetType } from '@/generated/prisma/client';
   ```

3. **Service files that import DB client being re-exported:**
   ```typescript
   // work-hours-calculator.ts
   import { prisma } from '@/lib/db/client';  // Server-only
   export function formatWorkHours() { ... }   // Pure function

   // Client component imports the pure function but gets prisma too
   import { formatWorkHours } from './work-hours-calculator';
   ```

## Solution

### Fix 1: Import Directly from Component Files (Not Barrels)

```typescript
// WRONG - imports entire barrel including server code
import { BudgetChart } from '@/features/budget';

// CORRECT - import directly from component file
import { BudgetChart } from '@/features/budget/components/BudgetChart';
```

### Fix 2: Split Server/Client Code in Service Files

```typescript
// work-hours-utils.ts (CLIENT-SAFE - no DB imports)
export function formatWorkHours(hours: number): string { ... }
export function calculateWorkHoursSync(amount: number, rate: number): number { ... }

// work-hours-calculator.ts (SERVER-ONLY)
import { prisma } from '@/lib/db/client';
export { formatWorkHours, calculateWorkHoursSync } from './work-hours-utils';
export async function getAfterTaxHourlyRate(): Promise<number> {
  const settings = await prisma.settings.findUnique(...);
  // ...
}
```

Then client components import from the utils file:
```typescript
// In client component
import { formatWorkHours } from './work-hours-utils';  // Safe!
```

### Fix 3: Use String Literals Instead of Prisma Enums

```typescript
// WRONG - imports Prisma runtime into client bundle
import { BudgetType } from '@/generated/prisma/client';
trpc.budget.list.useQuery({ type: BudgetType.MONTHLY });

// CORRECT - use string literal
const MONTHLY_BUDGET_TYPE = 'MONTHLY' as const;
trpc.budget.list.useQuery({ type: MONTHLY_BUDGET_TYPE });

// Or use type-only import (safe)
import type { BudgetType } from '@/generated/prisma/client';
```

### Fix 4: Configure serverExternalPackages (Alternative)

In `next.config.mjs`:
```javascript
const nextConfig = {
  experimental: {
    serverExternalPackages: ['@prisma/client', 'pg'],
  },
};
export default nextConfig;
```

This tells Turbopack to treat these as external server packages.

### Fix 5: Separate Barrel Exports by Type

```typescript
// features/budget/components/index.ts - Client-safe exports
export { BudgetChart } from './BudgetChart';
export { BudgetProgress } from './BudgetProgress';

// features/budget/services/index.ts - Server-only (don't import in client)
export * from './alerts';
export * from './comparison';

// features/budget/index.ts - Main barrel
export * from './components';  // Safe for client
export * from './types';       // Types are safe
// DON'T export services here if clients might import from this barrel
```

## Verification

1. Run `npm run build` - should complete without "Module not found" errors
2. Check that the import trace in any errors doesn't show `[Client Component Browser]` for server modules

## Example: Complete Fix Pattern

**Before (broken):**
```typescript
// page.tsx
'use client';
import { BudgetChart, calculateBudget } from '@/features/budget';
import { BudgetType } from '@/generated/prisma/client';

// budget/index.ts exports services with prisma imports
```

**After (working):**
```typescript
// page.tsx
'use client';
import { BudgetChart } from '@/features/budget/components/BudgetChart';

const MONTHLY_TYPE = 'MONTHLY' as const;
// Use string literal, or get the type from tRPC response
```

## Notes

- The `'use client'` directive creates a boundary—everything imported becomes part of the client bundle
- Tree shaking doesn't help because barrel files import everything before shaking
- Type imports (`import type { X }`) are always safe—they're removed at compile time
- This issue is more common with Turbopack than webpack due to stricter bundling
- If using `serverExternalPackages`, you still need to ensure the import paths are correct

## References

- [Next.js: Module Not Found](https://nextjs.org/docs/messages/module-not-found)
- [Prisma Issue #28096: adapter-pg Client Component Browser error](https://github.com/prisma/prisma/issues/28096)
- [Next.js: Server and Client Components](https://nextjs.org/docs/app/getting-started/server-and-client-components)
- [Vercel Blog: How we optimized package imports in Next.js](https://vercel.com/blog/how-we-optimized-package-imports-in-next-js)
- [Next.js Discussion: Barrel Exports mess with "use client"](https://github.com/vercel/next.js/discussions/65979)
- [The Hidden Trap in Next.js 13+ That's Breaking Your Server Components](https://medium.com/@eva.matova6/the-hidden-trap-in-next-js-13-thats-breaking-your-server-components-269cd202b8a9)
