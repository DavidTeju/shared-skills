---
name: vitest-class-mocking
description: |
  Fix "X is not a constructor" errors when mocking classes in Vitest. Use when:
  (1) vi.mock() with class that needs `new` throws "is not a constructor",
  (2) mock factory references variables defined outside the mock,
  (3) testing orchestrators/services that instantiate dependencies.
  Root cause: vi.mock() factories are hoisted before class definitions run.
user-invocable: false
---

# Vitest Class Constructor Mocking

Fix "X is not a constructor" errors when mocking classes in Vitest. Use when:
1. `vi.mock()` with class that needs `new` throws "is not a constructor"
2. Mock factory references variables defined outside the mock
3. Testing orchestrators/services that instantiate dependencies

## The Problem

`vi.mock()` factories are **hoisted** to the top of the file before any other code runs. This means:

```typescript
// THIS DOESN'T WORK - hoisting breaks it
class MockService {
  doThing = vi.fn();
}

vi.mock('./service', () => ({
  Service: MockService  // ERROR: MockService is undefined due to hoisting
}));
```

The mock factory runs before `MockService` is defined, causing "is not a constructor" errors.

## Solution: Define Classes Inline

Define mock classes directly inside the factory function:

```typescript
// CORRECT - inline class definition
vi.mock('./service', () => ({
  Service: class {
    doThing = vi.fn().mockResolvedValue('mocked');
  },
}));

vi.mock('./dependency', () => ({
  Dependency: class {
    name = 'Mock Dependency';
    process = vi.fn().mockResolvedValue([]);
  },
}));
```

## Alternative: vi.hoisted()

For complex mocks needing shared references, use `vi.hoisted()`:

```typescript
const { mockDetect } = vi.hoisted(() => ({
  mockDetect: vi.fn().mockResolvedValue([]),
}));

vi.mock('./detector', () => ({
  Detector: class {
    detect = mockDetect;  // Can reference hoisted variable
  },
}));

// Now you can configure mockDetect in tests
beforeEach(() => {
  mockDetect.mockClear();
});

it('handles errors', () => {
  mockDetect.mockRejectedValueOnce(new Error('fail'));
  // ...
});
```

## Common Patterns

### Mocking Multiple Related Classes

```typescript
vi.mock('../detectors/spending', () => ({
  SpendingDetector: class {
    type = 'SPENDING';
    name = 'Spending Detector';
    detect = vi.fn().mockResolvedValue([]);
  },
}));

vi.mock('../detectors/pattern', () => ({
  PatternDetector: class {
    type = 'PATTERN';
    name = 'Pattern Detector';
    detect = vi.fn().mockResolvedValue([]);
  },
}));
```

### Mocking Service Classes with Prisma

```typescript
vi.mock('../services/deduplication', () => ({
  DeduplicationService: class {
    deduplicate = vi.fn((items: unknown[]) => Promise.resolve(items));
  },
}));
```

## Key Points

1. **Hoisting is automatic** - `vi.mock()` always runs first regardless of position in file
2. **Inline classes work** - Class expressions inside the factory are defined at hoist time
3. **Use vi.hoisted() for shared mocks** - When you need to reference the mock in tests
4. **Keep mocks simple** - Complex mock logic often indicates test design issues

## References

- [Vitest Mocking Documentation](https://vitest.dev/guide/mocking.html)
- [vi.hoisted() API](https://vitest.dev/api/vi.html#vi-hoisted)
