# Debugging Strategy: Async & Race Conditions

## Symptoms

- Works sometimes, fails randomly
- Fails under load but works with single requests
- Test passes in isolation, fails in suite
- "Heisenbug" - bug disappears when you add logging
- Timing-dependent behavior
- "It worked yesterday"

## Common Causes

1. **Race conditions**: Multiple async operations competing for same resource
2. **Missing await**: Forgetting to await a Promise
3. **Concurrent modifications**: Two processes updating same data
4. **Stale closures**: Callback captures old value
5. **Event ordering**: Events arrive in unexpected order
6. **Cache inconsistency**: Cached data out of sync with source

## Diagnostic Approach

### Step 1: Add Timestamps to Logs

```typescript
function log(context: string, message: string) {
  const timestamp = new Date().toISOString();
  const ms = Date.now() % 100000;  // Last 5 digits for easier reading
  console.log(`[${ms}] ${context}: ${message}`);
}

// Usage
log('fetchUser', 'Starting fetch for user 123');
const user = await fetchUser(123);
log('fetchUser', 'Completed fetch, got user: ' + user.name);
```

This helps you see the ORDER of operations:
```
[45123] fetchUser: Starting fetch for user 123
[45125] updateUser: Starting update for user 123  // <-- Uh oh, concurrent!
[45230] updateUser: Completed update
[45235] fetchUser: Completed fetch, got user: John  // <-- Stale data!
```

### Step 2: Check for Missing Awaits

```typescript
// WRONG - Missing await
async function processItems(items) {
  items.forEach(async (item) => {
    await processItem(item);  // These run concurrently, not sequentially!
  });
  console.log('Done');  // Logs BEFORE items are processed!
}

// RIGHT - Properly awaited
async function processItems(items) {
  for (const item of items) {
    await processItem(item);  // Sequential
  }
  console.log('Done');  // Logs after all items processed

  // OR for parallel:
  await Promise.all(items.map(item => processItem(item)));
  console.log('Done');  // Logs after all items processed
}
```

### Step 3: Track Concurrent Operations

```typescript
let operationCount = 0;
const operations = new Map<string, { start: number; context: string }>();

async function trackedOperation<T>(
  name: string,
  context: string,
  fn: () => Promise<T>
): Promise<T> {
  const id = `${name}-${++operationCount}`;
  operations.set(id, { start: Date.now(), context });

  console.log(`[START] ${id}: ${context}`);
  console.log(`  Active operations: ${operations.size}`);

  if (operations.size > 1) {
    console.log(`  CONCURRENT with: ${[...operations.keys()].filter(k => k !== id).join(', ')}`);
  }

  try {
    const result = await fn();
    console.log(`[END] ${id}: completed in ${Date.now() - operations.get(id)!.start}ms`);
    return result;
  } finally {
    operations.delete(id);
  }
}

// Usage
await trackedOperation('updateUser', `userId=${userId}`, async () => {
  return await db.user.update({ ... });
});
```

### Step 4: Force Sequential Execution

If you suspect a race condition, force operations to be sequential to confirm:

```typescript
// Add a mutex/lock
const mutex = new Map<string, Promise<void>>();

async function withLock<T>(key: string, fn: () => Promise<T>): Promise<T> {
  const existing = mutex.get(key);
  if (existing) {
    console.log(`Waiting for lock on ${key}`);
    await existing;
  }

  let resolve: () => void;
  const lock = new Promise<void>(r => { resolve = r; });
  mutex.set(key, lock);

  try {
    return await fn();
  } finally {
    mutex.delete(key);
    resolve!();
  }
}

// Usage - if bug disappears, you have a race condition
await withLock(`user-${userId}`, async () => {
  const user = await getUser(userId);
  await updateUser(userId, { ...user, name: 'New Name' });
});
```

### Step 5: Check for Stale Closures

```typescript
// Bug: closures capture stale values
function setupHandler() {
  let count = 0;

  button.onclick = () => {
    count++;  // This might not see updates from other handlers
    console.log(count);
  };

  setTimeout(() => {
    count = 100;  // This update might not be seen by onclick
  }, 1000);
}

// Fix: use refs or state management
function setupHandler() {
  const countRef = { current: 0 };

  button.onclick = () => {
    countRef.current++;
    console.log(countRef.current);
  };
}
```

## Real Example: Database Update Race

**Symptom**: User profile sometimes shows old data after update

**Diagnosis**:
```typescript
// Added tracking
console.log(`[${Date.now()}] Fetching user ${id}`);
const user = await getUser(id);
console.log(`[${Date.now()}] Got user, updating`);
await updateUser(id, newData);
console.log(`[${Date.now()}] Update complete`);

// Output showed:
// [1000] Fetching user 123
// [1001] Fetching user 123  <-- Second request started!
// [1050] Got user, updating (first request)
// [1051] Got user, updating (second request with OLD data)
// [1100] Update complete (first)
// [1101] Update complete (second - OVERWRITES first!)
```

**Root cause**: Two concurrent requests both read old data, then both write, second write wins

**Fix**: Use optimistic locking or transactions

## Common Fixes by Cause

| Cause | Fix |
|-------|-----|
| Missing await | Add await, use Promise.all for parallel |
| Race condition | Add mutex/lock, use transactions |
| Concurrent modifications | Optimistic locking, versioning |
| Stale closure | Use refs, move state outside closure |
| Event ordering | Add sequence numbers, idempotency |
| Cache inconsistency | Invalidate on write, use cache-aside pattern |

## Testing for Race Conditions

```typescript
// Run operation multiple times concurrently to expose races
async function stressTest() {
  const results = await Promise.all(
    Array(10).fill(null).map(async (_, i) => {
      console.log(`Starting operation ${i}`);
      try {
        return await riskyOperation();
      } catch (error) {
        return { error: error.message, index: i };
      }
    })
  );

  console.log('Results:', results);
  const errors = results.filter(r => r.error);
  if (errors.length > 0) {
    console.log('RACE CONDITION DETECTED:', errors);
  }
}
```
