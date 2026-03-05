---
name: prisma-7-driver-adapter
description: |
  Fix Prisma 7 "engine type client requires adapter" error after upgrading from
  Prisma 6. Use when: (1) Error "Using engine type 'client' requires either
  'adapter' or 'accelerateUrl' to be provided to PrismaClient constructor",
  (2) PrismaClientConstructorValidationError after Prisma 7 upgrade,
  (3) Setting engineType = "library" doesn't fix the error, (4) Next.js build
  fails after upgrading Prisma to v7.x.
author: Claude Code
user-invocable: false
---

# Prisma 7 Driver Adapter Requirement

## Problem

Prisma 7 introduced a breaking change where the old Rust-based query engine is no
longer the default. The new "client" engine type requires a driver adapter for all
database connections. Simply setting `engineType = "library"` in the schema generator
block does NOT work - this is a common misconception during the upgrade.

This is non-obvious because:
1. The error message mentions "adapter" but doesn't explain what changed
2. Setting `engineType = "library"` seems like it should revert to the old behavior
3. The old `new PrismaClient()` pattern compiled fine but fails at runtime
4. Cache clearing and regeneration don't help

## Context / Trigger Conditions

This skill applies when you see:

**Primary error (exact match):**
```
Error [PrismaClientConstructorValidationError]: Using engine type "client" requires either "adapter" or "accelerateUrl" to be provided to PrismaClient constructor.
```

**Related symptoms:**
- Upgrading from Prisma 6.x to Prisma 7.x
- Next.js build fails with PrismaClientConstructorValidationError
- `engineType = "library"` in schema.prisma doesn't resolve the error
- Clearing `.next`, `node_modules/.prisma`, and regenerating doesn't help
- `npx prisma generate` succeeds but application fails at runtime

**Environment indicators:**
- Prisma version 7.0.0 or higher
- PostgreSQL, MySQL, SQLite, or other supported database
- Any framework (Next.js, Express, Fastify, etc.)

## Solution

### Step 1: Install Driver Adapter Package

For PostgreSQL:
```bash
npm install @prisma/adapter-pg pg
```

For MySQL:
```bash
npm install @prisma/adapter-mysql mysql2
```

For SQLite:
```bash
npm install @prisma/adapter-libsql @libsql/client
```

For PlanetScale:
```bash
npm install @prisma/adapter-planetscale @planetscale/database
```

### Step 2: Update Prisma Client Initialization

Replace the old pattern with the adapter pattern.

**For PostgreSQL:**

```typescript
// lib/prisma.ts
import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'

const connectionString = process.env.DATABASE_URL!

// Create adapter with connection string
const adapter = new PrismaPg({ connectionString })

// Global singleton pattern for development
const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined
}

export const prisma = globalForPrisma.prisma ?? new PrismaClient({ adapter })

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma
```

**For MySQL:**

```typescript
// lib/prisma.ts
import { PrismaClient } from '@prisma/client'
import { PrismaMySql } from '@prisma/adapter-mysql'
import mysql from 'mysql2/promise'

const connectionString = process.env.DATABASE_URL!

const pool = mysql.createPool(connectionString)
const adapter = new PrismaMySql(pool)

const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined
}

export const prisma = globalForPrisma.prisma ?? new PrismaClient({ adapter })

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma
```

### Step 3: Update Schema (Optional but Recommended)

You can remove or keep the generator config. The adapter in code takes precedence:

```prisma
generator client {
  provider = "prisma-client-js"
  // engineType is optional when using adapter in code
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}
```

### Step 4: Regenerate and Clear Cache

```bash
# Clear all caches
rm -rf .next node_modules/.prisma

# Regenerate Prisma client
npx prisma generate

# Rebuild application
npm run build
```

## Verification

After applying fixes:

1. Run `npx prisma generate` - should complete without errors
2. Run `npm run build` - should complete without PrismaClientConstructorValidationError
3. Run `npm run dev` and test a database query - should work
4. Check application logs for any connection errors

## Example

**Scenario**: Upgrading a Next.js app from Prisma 6.5.0 to Prisma 7.3.0

**Before** (failing code):
```typescript
// lib/prisma.ts - OLD PATTERN (broken in Prisma 7)
import { PrismaClient } from '@prisma/client'

const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined
}

export const prisma = globalForPrisma.prisma ?? new PrismaClient()

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma
```

**Error:**
```
Error [PrismaClientConstructorValidationError]: Using engine type "client"
requires either "adapter" or "accelerateUrl" to be provided to PrismaClient constructor.
```

**After** (working code):
```typescript
// lib/prisma.ts - NEW PATTERN (Prisma 7+)
import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'

const connectionString = process.env.DATABASE_URL!
const adapter = new PrismaPg({ connectionString })

const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined
}

export const prisma = globalForPrisma.prisma ?? new PrismaClient({ adapter })

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma
```

## Notes

- **Do NOT rely on `engineType = "library"`** - This setting alone does not work in Prisma 7. The adapter is required regardless of engine type configuration.

- **Prisma Accelerate alternative**: If using Prisma Accelerate, you can provide `accelerateUrl` instead of an adapter:
  ```typescript
  const prisma = new PrismaClient({
    accelerateUrl: process.env.PRISMA_ACCELERATE_URL
  })
  ```

- **Connection pooling**: The driver adapters handle connection pooling differently than the old engine. For PostgreSQL with `pg`, you can configure pooling:
  ```typescript
  import { Pool } from 'pg'
  const pool = new Pool({ connectionString, max: 10 })
  const adapter = new PrismaPg(pool)
  ```

- **TypeScript types**: Ensure `@types/pg` is installed for PostgreSQL type definitions:
  ```bash
  npm install -D @types/pg
  ```

- **Migration from Prisma 6**: This is a one-way migration. The new adapter pattern is the only supported method in Prisma 7+.

- **Serverless environments**: The adapter pattern works well with serverless. Each cold start creates a new adapter instance, similar to the old singleton pattern.

- **Related issue**: If you also see connection pool exhaustion errors, see the `prisma-connection-pool-exhaustion` skill for additional configuration.
