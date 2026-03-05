---
name: git-worktree-nextjs-prisma
description: |
  Set up git worktrees correctly for Next.js projects with Prisma. Use when:
  (1) "Cannot find module '.prisma/client/default'" error in new worktree,
  (2) API routes return 500 errors in worktree but work in main repo,
  (3) Setting up parallel development branches for UI comparison.
  Covers npm install, prisma generate, and .env file copying.
author: Claude Code
user-invocable: false
---

# Git Worktree Setup for Next.js + Prisma

## Problem
New git worktrees for Next.js projects with Prisma fail with cryptic errors because
the generated Prisma client and environment files aren't included in git.

## Context / Trigger Conditions
- Created a git worktree with `git worktree add`
- Running `npm run dev` shows "Cannot find module '.prisma/client/default'"
- API routes return 500 errors with empty browser console
- Server logs show Prisma client module resolution failure

## Solution

### Complete Worktree Setup Checklist

```bash
# 1. Create the worktree
git worktree add /path/to/worktree branch-name -b new-branch-name

# 2. Copy environment files (gitignored, so not in worktree)
cp .env.local /path/to/worktree/
cp .env /path/to/worktree/  # if exists

# 3. Install dependencies
cd /path/to/worktree
npm install

# 4. Generate Prisma client (CRITICAL - often forgotten)
npx prisma generate

# 5. Now start the dev server
npm run dev -- -p 3001  # Use different port to run alongside main
```

### Why Each Step Matters

1. **npm install**: Creates `node_modules/` - worktrees share git files but NOT node_modules
2. **prisma generate**: Creates `.prisma/client/` inside node_modules - this is NOT installed from npm, it's generated from your schema
3. **.env.local**: Contains database URLs, API keys - gitignored so never in worktree

### Automation Script

For frequently creating worktrees:

```bash
#!/bin/bash
# setup-worktree.sh

WORKTREE_PATH=$1
BRANCH=$2
PORT=${3:-3001}

git worktree add "$WORKTREE_PATH" "$BRANCH" -b "$BRANCH"
cp .env.local "$WORKTREE_PATH/"
cd "$WORKTREE_PATH"
npm install
npx prisma generate
echo "Ready! Run: cd $WORKTREE_PATH && npm run dev -- -p $PORT"
```

## Verification
- `npm run dev` starts without Prisma module errors
- API routes return data instead of 500 errors
- Database operations work correctly

## Example

```bash
# Create 3 UI variants for comparison
for i in 1 2 3; do
  git worktree add ../worktrees/ui-variant-$i main -b ui-variant-$i
  cp .env.local ../worktrees/ui-variant-$i/
  cd ../worktrees/ui-variant-$i && npm install && npx prisma generate
done

# Run each on different ports
# Variant 1: port 3001
# Variant 2: port 3002
# Variant 3: port 3003
```

## Notes
- Worktrees share `.git` but NOT `node_modules`, `.next`, or gitignored files
- Each worktree needs its own `npx prisma generate` even with identical schemas
- If schema changes, re-run `prisma generate` in each worktree
- For Prisma 7+, the generated client location may differ - check error messages

## References
- [Git Worktrees Documentation](https://git-scm.com/docs/git-worktree)
- [Prisma Client Generation](https://www.prisma.io/docs/concepts/components/prisma-client/working-with-prismaclient/generating-prisma-client)
