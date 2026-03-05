# Debugging Strategy: Misleading Errors

## Symptoms

- Error message points to the wrong file/line
- Error message describes a symptom, not the cause
- Stack trace ends in framework/library code, not your code
- "undefined is not a function" or similar generic errors
- Error occurs far from where the bug actually is

## Common Causes

1. **Async stack traces**: Error thrown in callback/promise loses original context
2. **Proxy/wrapper objects**: Error occurs in wrapper, not original code
3. **Lazy evaluation**: Error triggered when value is accessed, not when bug was introduced
4. **Type coercion**: JavaScript converts invalid values silently until they're used
5. **Bundler/transpiler**: Source maps incorrect or missing
6. **Cascading failures**: First error causes second error which is what you see

## Diagnostic Approach

### Step 1: Don't Trust the Error Location

The error message tells you where JavaScript gave up, not where you made a mistake.

```javascript
// Error says: "Cannot read property 'name' of undefined" at line 50

// Line 50:
console.log(user.name);  // <-- Error shows here

// But the BUG is at line 20:
const user = users.find(u => u.id === id);  // <-- Returns undefined when id not found
```

### Step 2: Trace Backwards from Error

Work backwards from the error to find the source:

```typescript
// Error: Cannot read 'amount' of undefined at processTransaction

// Trace backwards:
console.log('processTransaction input:', JSON.stringify(transaction));

function processTransaction(transaction) {
  console.log('transaction:', transaction);
  console.log('transaction.amount:', transaction.amount);  // Error here
}

// Keep tracing upstream:
function getTransaction(id) {
  const tx = transactions.find(t => t.id === id);
  console.log('getTransaction result:', tx);  // <-- Find where undefined comes from
  return tx;
}
```

### Step 3: Log at Every Transformation

When data passes through multiple functions, log at each step:

```typescript
function pipeline(input) {
  console.log('1. Input:', input);

  const step1 = transformA(input);
  console.log('2. After transformA:', step1);

  const step2 = transformB(step1);
  console.log('3. After transformB:', step2);

  const step3 = transformC(step2);
  console.log('4. After transformC:', step3);

  return step3;
}
```

### Step 4: Check for Type Coercion Issues

JavaScript's type coercion hides bugs until later:

```typescript
// This doesn't error immediately:
const amount = "100" + 50;  // "10050" (string!)

// Error only shows up later:
if (amount > 200) { ... }  // Works (string comparison)
const tax = amount * 0.1;   // 1005 (unexpected!)
```

Add explicit checks:

```typescript
console.log('amount:', amount, 'type:', typeof amount);
if (typeof amount !== 'number') {
  console.error('UNEXPECTED TYPE for amount');
}
```

### Step 5: Handle Async Errors Properly

Async errors lose context. Add error boundaries:

```typescript
// Bad - loses context
items.forEach(async (item) => {
  await processItem(item);  // Error here loses which item caused it
});

// Good - preserves context
for (const item of items) {
  try {
    console.log('Processing item:', item.id);
    await processItem(item);
  } catch (error) {
    console.error('Error processing item:', item.id);
    console.error('Item data:', JSON.stringify(item));
    throw error;
  }
}
```

## Real Examples

### Example 1: "undefined is not a function"

**Error**: `TypeError: undefined is not a function at Object.<anonymous>`

**Actual cause**: Importing a named export that doesn't exist

```typescript
// Error shows at call site:
doSomething();  // <-- Error here

// But bug is in import:
import { doSomething } from './utils';  // doSomething not exported!
```

**Fix**: Check the import and the source file's exports

### Example 2: Database Error Points to Wrong Query

**Error**: `Error: Cannot insert NULL into column 'userId'` on INSERT statement

**Actual cause**: The bug is in the code that's supposed to provide userId

```typescript
// Error says it's here:
await db.insert({ name, email, userId });

// But bug is earlier:
const userId = session.user?.id;  // undefined because session is null
```

**Fix**: Trace where userId comes from, add validation earlier

### Example 3: React "Objects are not valid as React child"

**Error**: At some component deep in the tree

**Actual cause**: Passing object where string expected, often from parent

```typescript
// Error in <Label>:
<Label>{value}</Label>

// But value was set incorrectly upstream:
const value = await fetchData();  // Returns object, expected string
```

## Techniques for Better Error Messages

### 1. Validation at Boundaries

```typescript
function processUser(user: User) {
  // Validate inputs immediately
  if (!user) throw new Error('processUser: user is required');
  if (!user.id) throw new Error('processUser: user.id is required');
  if (typeof user.name !== 'string') {
    throw new Error(`processUser: expected user.name to be string, got ${typeof user.name}`);
  }

  // Now proceed...
}
```

### 2. Contextual Error Wrapping

```typescript
try {
  return await riskyOperation(data);
} catch (error) {
  throw new Error(
    `Failed to process ${data.type} with id ${data.id}: ${error.message}`,
    { cause: error }
  );
}
```

### 3. Assert Functions

```typescript
function assertDefined<T>(value: T | undefined, name: string): T {
  if (value === undefined) {
    throw new Error(`Expected ${name} to be defined`);
  }
  return value;
}

// Usage
const user = assertDefined(users.find(u => u.id === id), `user with id ${id}`);
```
