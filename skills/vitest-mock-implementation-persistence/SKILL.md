---
name: vitest-mock-implementation-persistence
description: |
  Fix Vitest test failures where mocked methods return undefined or "is not a function" errors
  in tests that worked before. Use when: (1) tests fail with "expected undefined to be X",
  (2) TypeError "X is not a function" in mocked methods, (3) one test passes but subsequent
  tests in the same describe block fail, (4) tests pass in isolation but fail when run together.
  Root cause: vi.clearAllMocks() only clears call history, NOT mockImplementation. A previous
  test's mockImplementation persists to subsequent tests.
author: Claude Code
user-invocable: false
---

# Vitest Mock Implementation Persistence

## Problem

Tests mysteriously fail with "undefined" results or "is not a function" errors when run
after other tests, but pass in isolation. This happens because `vi.clearAllMocks()` does
NOT reset mock implementations set via `mockImplementation()`.

## Context / Trigger Conditions

Use this skill when:
- Test A passes, but Test B fails with "expected undefined to be X"
- `TypeError: tx.something.method is not a function` in mocked Prisma transactions
- Tests pass when run individually (`vitest run -t "test name"`) but fail in full suite
- A test sets `mockFn.mockImplementation()` with a limited object (e.g., only some methods)
- `beforeEach` uses `vi.clearAllMocks()` but tests still interfere with each other

Specific error patterns:
```
AssertionError: expected undefined to be 1 // Object.is equality
TypeError: tx.transaction.updateMany is not a function
```

## Root Cause

```javascript
// vi.mock sets up the mock factory ONCE at module load
vi.mock('@/lib/db/client', () => ({
  prisma: {
    $transaction: vi.fn((callback) => callback(prismaMock)),
  },
}));

// Test A overrides the implementation
mockPrisma.$transaction.mockImplementation(async (callback) => {
  return callback({ account: { create: vi.fn() } }); // Limited mock object!
});

// vi.clearAllMocks() runs in beforeEach - ONLY clears call history
vi.clearAllMocks();
// ❌ mockImplementation from Test A still persists!

// Test B fails because it gets Test A's limited mock object
// which doesn't have the methods Test B needs
```

## Solution

### Option 1: Reset implementation in beforeEach (Recommended)

```javascript
beforeEach(() => {
  vi.clearAllMocks();
  // Explicitly reset to default implementation
  mockPrisma.$transaction.mockImplementation((callback) => {
    if (typeof callback === 'function') {
      return callback(mockPrisma); // Pass full mock object
    }
    return Promise.resolve(callback); // For batch transactions
  });
});
```

### Option 2: Use vi.resetAllMocks() (Use with caution)

```javascript
beforeEach(() => {
  vi.resetAllMocks(); // Clears history AND resets implementations to undefined
  // ⚠️ Warning: This makes all mocks return undefined!
  // You'll need to re-setup ALL mock return values in each test
});
```

### Option 3: Each test sets up its own complete mock

```javascript
it('test A', async () => {
  mockPrisma.$transaction.mockImplementation(async (callback) => {
    return callback({
      account: { create: vi.fn(), update: vi.fn(), findMany: vi.fn() },
      transaction: { create: vi.fn(), update: vi.fn(), updateMany: vi.fn() },
    });
  });
  // ... test code
});
```

## Key Differences

| Method | Clears History | Resets Implementation | Use When |
|--------|---------------|----------------------|----------|
| `vi.clearAllMocks()` | ✅ | ❌ | Default choice, but watch for impl persistence |
| `vi.resetAllMocks()` | ✅ | ✅ (to undefined) | Need clean slate, will re-setup all mocks |
| `vi.restoreAllMocks()` | ✅ | ✅ (to original) | Only for `vi.spyOn` mocks |

## Verification

After applying the fix:
1. Run the full test suite: `npm run test`
2. Verify previously failing tests now pass
3. Check that Test A still passes (didn't break it)

## Example: Prisma $transaction Mock

Common pattern that causes this issue:

```javascript
// ❌ BAD: Test A creates limited mock that persists
it('should create connection', async () => {
  mockPrisma.$transaction.mockImplementation(async (callback) => {
    return callback({
      bankConnection: { create: vi.fn().mockResolvedValue({ id: '1' }) },
      account: { create: vi.fn().mockResolvedValue({ id: '2' }) },
      // Missing: transaction.updateMany, account.findMany, etc.
    });
  });
});

// Test B fails because it inherits the limited mock ^^
it('should sync connection', async () => {
  // Uses inherited mock which doesn't have transaction.updateMany
  // → TypeError: tx.transaction.updateMany is not a function
});
```

Fix:
```javascript
// ✅ GOOD: Reset to full mock in beforeEach
beforeEach(() => {
  vi.clearAllMocks();
  mockPrisma.$transaction.mockImplementation((callback) => {
    if (typeof callback === 'function') {
      return callback(mockPrisma); // Full mock with all methods
    }
    return Promise.resolve(callback);
  });
});
```

## Notes

- This applies equally to Jest (same behavior with `jest.clearAllMocks()`)
- The issue is subtle because tests pass in isolation - you only see it in full suite runs
- Consider enabling `mockReset: true` in vitest.config.ts for automatic reset, but be aware
  this makes all mocks return undefined by default
- When debugging, run specific test files to isolate which test is setting the problematic
  implementation: `vitest run src/feature/__tests__/file.test.ts`

## References

- [Epic Web Dev: Clearing vs Resetting vs Restoring Mocks](https://www.epicweb.dev/the-difference-between-clearing-resetting-and-restoring-mocks)
- [Vitest Vi API Documentation](https://vitest.dev/api/vi)
- [Far World Labs: Clearing Mocks in Vitest](https://www.farworldlabs.com/posts/clearing-mocks-in-vitest/)
- [Vitest Discussion: Clearing and restoring mocks clarification](https://github.com/vitest-dev/vitest/discussions/2784)
