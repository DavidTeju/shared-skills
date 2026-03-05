# Debugging Strategy: Integration & Third-Party Issues

## Symptoms

- Works with mocks, fails with real service
- Error comes from library/framework code
- Behavior differs from documentation
- Works in development, fails in production
- Sudden breakage after dependency update

## Common Causes

1. **API contract mismatch**: Library expects different input format
2. **Undocumented behavior**: Library has quirks not in docs
3. **Version incompatibility**: Library version differs from examples
4. **Environment differences**: Different config in dev vs prod
5. **Rate limiting / quotas**: External service throttling
6. **Network issues**: Timeouts, DNS, SSL problems
7. **Library bugs**: Actual bugs in third-party code

## Diagnostic Approach

### Step 1: Isolate the Integration Point

Create a minimal script that ONLY tests the third-party integration:

```typescript
#!/usr/bin/env npx tsx
/**
 * Test [Library Name] integration in isolation
 */

import 'dotenv/config';
import { ThirdPartyLib } from 'third-party-lib';

async function main() {
  console.log('Testing ThirdPartyLib...\n');

  // 1. Test basic initialization
  console.log('1. Initializing...');
  const client = new ThirdPartyLib({ apiKey: process.env.API_KEY });
  console.log('   OK\n');

  // 2. Test with minimal input
  console.log('2. Minimal input test...');
  const result1 = await client.doThing({ value: 1 });
  console.log('   Result:', result1);
  console.log('   OK\n');

  // 3. Test with your actual input
  console.log('3. Real input test...');
  const myInput = { /* your actual input */ };
  console.log('   Input:', JSON.stringify(myInput));
  const result2 = await client.doThing(myInput);
  console.log('   Result:', result2);
  console.log('   OK\n');
}

main().catch(err => {
  console.error('FAILED:', err);
  process.exit(1);
});
```

### Step 2: Check Input/Output Format

Libraries often have undocumented expectations. Log everything:

```typescript
// Log EXACTLY what you're sending
const input = prepareInput(data);
console.log('Sending to library:');
console.log('  Type:', typeof input);
console.log('  JSON:', JSON.stringify(input, null, 2));
console.log('  Keys:', Object.keys(input));

// For arrays, check element types
if (Array.isArray(input)) {
  console.log('  Array length:', input.length);
  console.log('  First element type:', typeof input[0]);
  console.log('  Sample element:', JSON.stringify(input[0]));
}

const result = await library.process(input);

// Log what you got back
console.log('Received from library:');
console.log('  Type:', typeof result);
console.log('  JSON:', JSON.stringify(result, null, 2));
```

### Step 3: Compare with Working Example

Find a working example (from docs, tests, or issues) and compare:

```typescript
// From documentation/working example
const workingInput = {
  matrix: [[1, 2], [3, 4]],
};

// Your input
const myInput = {
  matrix: [[1, Infinity], [3, 4]],  // <-- Spot the difference!
};

// Test both
console.log('Working example result:', await lib.process(workingInput));
console.log('My input result:', await lib.process(myInput));
```

### Step 4: Check Version and Changelog

```bash
# Check installed version
npm ls third-party-lib

# Check if there's a newer version
npm outdated third-party-lib

# Read changelog for breaking changes
# Look at GitHub releases, CHANGELOG.md
```

### Step 5: Search for Similar Issues

```typescript
// Before debugging further, search:
// 1. GitHub issues for the library
// 2. Stack Overflow with error message
// 3. Library's Discord/forum

// Common search patterns:
// "[library-name] [exact error message]"
// "[library-name] [your use case] not working"
// "[library-name] [input type] issue"
```

## Real Example: munkres-js Infinity Bug

**Symptom**: Hungarian algorithm function hangs with no error

**Isolation test**:
```typescript
import munkres from 'munkres-js';

// Test 1: Simple input (works)
const simple = [[1, 2], [3, 4]];
console.log('Simple:', munkres(simple));  // OK

// Test 2: With Infinity (HANGS)
const withInfinity = [[1, Infinity], [Infinity, 4]];
console.log('With Infinity:', munkres(withInfinity));  // Never prints!
```

**Discovery**: Library doesn't handle JavaScript Infinity values

**Investigation**:
- Checked GitHub issues: Found #7 about undefined values causing infinite loops
- Same root cause: Invalid values break internal arithmetic

**Solution**: Sanitize input before calling library

## Common Integration Issues and Fixes

| Issue | Detection | Fix |
|-------|-----------|-----|
| Input format | Compare with working example | Transform data to expected format |
| Type coercion | Log typeof for all values | Explicit type conversion |
| Special values (Infinity, NaN) | Check for non-finite numbers | Sanitize input |
| Missing required fields | Compare with schema/docs | Add required fields |
| Version mismatch | Check package.json vs docs | Pin to documented version |
| Environment vars | Log process.env.VAR | Ensure vars are set |
| Network issues | Add timeout, retry logic | Handle network errors |

## Wrapper Pattern for Unreliable Libraries

```typescript
async function safeLibraryCall<T>(
  input: unknown,
  libraryFn: (input: unknown) => T
): Promise<T> {
  // 1. Validate input
  const sanitizedInput = sanitizeInput(input);

  // 2. Log for debugging
  console.log('Calling library with:', JSON.stringify(sanitizedInput).slice(0, 200));

  // 3. Add timeout
  const timeoutMs = 5000;
  const result = await Promise.race([
    Promise.resolve(libraryFn(sanitizedInput)),
    new Promise<never>((_, reject) =>
      setTimeout(() => reject(new Error('Library call timed out')), timeoutMs)
    ),
  ]);

  // 4. Validate output
  if (!isValidOutput(result)) {
    throw new Error(`Invalid library output: ${JSON.stringify(result)}`);
  }

  return result;
}
```

## When to Give Up on a Library

Consider alternatives when:

1. **Unmaintained**: No commits or issue responses in 6+ months
2. **Known bug affects you**: Issue open with no fix planned
3. **Poor documentation**: Can't figure out correct usage
4. **Better alternatives exist**: Newer library handles your case

Example: `munkres-js` doesn't handle Infinity, but `munkres-algorithm` does.

```bash
# Find alternatives
npm search hungarian algorithm

# Check alternatives on bundlephobia, npm trends
```
