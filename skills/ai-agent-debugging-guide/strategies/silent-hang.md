# Debugging Strategy: Silent Hang

## Symptoms

- Code execution stops/freezes with no error thrown
- Function calls don't return
- Program appears stuck but doesn't crash
- No console output, no logs, no stack trace

## Common Causes

1. **Infinite loops**: Loop condition never becomes false
2. **Library bugs**: Third-party code hangs on certain inputs
3. **Deadlocks**: Waiting for resources that will never be available
4. **Invalid input to algorithms**: Values like `Infinity`, `NaN`, `undefined` breaking math
5. **Blocking I/O**: Waiting for network/file operations that never complete
6. **Promise never resolves**: Async operations that never complete or reject

## Diagnostic Approach

### Step 1: Add Progress Logging to Loops

```typescript
let iteration = 0;
const total = items.length;

for (const item of items) {
  iteration++;
  console.log(`Processing ${iteration}/${total}...`);

  // ... your code ...

  console.log(`  Completed ${iteration}`);
}
```

If output stops at "Processing X/Y" but never shows "Completed X", you've found the hanging iteration.

### Step 2: Bracket Suspicious Calls

```typescript
console.log('Before suspicious call');
console.log('  Input:', JSON.stringify(input).slice(0, 200));

const result = suspiciousFunction(input);  // <-- suspected hang

console.log('After suspicious call');
console.log('  Output:', JSON.stringify(result).slice(0, 200));
```

### Step 3: Inspect the Problematic Input

Once you identify WHICH iteration hangs, examine that specific input:

```typescript
if (iteration === problematicIteration) {
  console.log('PROBLEMATIC INPUT:');
  console.log(JSON.stringify(input, null, 2));

  // Check for known problem values
  console.log('Has Infinity?', hasInfinity(input));
  console.log('Has NaN?', hasNaN(input));
  console.log('Has undefined?', hasUndefined(input));
}
```

### Step 4: Test the Call in Isolation

Create minimal reproduction:

```typescript
// Minimal test of the hanging call
const problematicInput = /* paste the logged input */;
console.log('Testing with isolated input...');
const result = suspiciousFunction(problematicInput);
console.log('Result:', result);
```

## Real Example: munkres-js Infinity Bug

**Symptom**: Hungarian algorithm function hangs, no error

**Diagnosis**:
```typescript
for (const bucket of buckets) {
  console.log(`Processing bucket ${i}/${total}...`);

  // Build matrix...
  console.log(`  Matrix size: ${matrix.length}x${matrix[0]?.length}`);

  // Check for problematic values
  const hasInfinity = matrix.some(row => row.some(v => v === Infinity));
  console.log(`  Has Infinity: ${hasInfinity}`);

  console.log(`  Running munkres...`);
  const assignments = munkres(matrix);
  console.log(`  Got ${assignments.length} assignments`);  // Never reached!
}
```

**Finding**: Output stopped after "Running munkres..." on a bucket where `hasInfinity: true`

**Root Cause**: `Infinity - Infinity = NaN` breaks the algorithm's arithmetic

**Fix**: Replace `Infinity` with large finite number before calling munkres

## Common Fixes by Cause

| Cause | Fix |
|-------|-----|
| Infinite loop | Fix loop termination condition |
| Invalid math values | Sanitize inputs (replace Infinity/NaN with finite numbers) |
| Library bug | Work around with input sanitization or use alternative library |
| Deadlock | Review locking/resource acquisition order |
| Promise never resolves | Add timeouts, check for missing resolve/reject calls |
| Blocking I/O | Add timeouts, verify endpoint/file exists |

## Timeout Wrapper Pattern

For calls that might hang, wrap with timeout:

```typescript
async function withTimeout<T>(
  promise: Promise<T>,
  ms: number,
  context: string
): Promise<T> {
  const timeout = new Promise<never>((_, reject) =>
    setTimeout(() => reject(new Error(`Timeout after ${ms}ms: ${context}`)), ms)
  );
  return Promise.race([promise, timeout]);
}

// Usage
const result = await withTimeout(
  riskyAsyncOperation(),
  5000,
  'riskyAsyncOperation'
);
```

For sync operations (harder - requires worker threads or child process).
