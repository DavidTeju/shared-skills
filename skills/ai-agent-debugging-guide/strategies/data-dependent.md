# Debugging Strategy: Data-Dependent Bugs

## Symptoms

- Works with test data, fails with production data
- Works for some users/accounts, fails for others
- "It works on my machine"
- Bug appears after data migration or import
- Intermittent failures that correlate with specific records

## Common Causes

1. **Edge case values**: Empty strings, zero, null, negative numbers, Unicode
2. **Scale issues**: Works with 10 items, fails with 10,000
3. **Data format variations**: Different date formats, number formats, encodings
4. **Missing/optional fields**: Data has fields that test data doesn't
5. **Invalid data**: Production data has corruption or invalid values
6. **Boundary conditions**: Values at limits (max int, empty array, etc.)

## Diagnostic Approach

### Step 1: Get Real Data

Don't debug with fake data. Pull actual failing cases:

```typescript
// Create a debug script that uses real DB data
import { prisma } from '../src/lib/db/client';

async function main() {
  // Get the ACTUAL data that's causing problems
  const transactions = await prisma.transaction.findMany({
    where: { accountId: 'the-failing-account' },
  });

  console.log('Real transactions:', transactions.length);

  // Now run your logic on real data
  for (const tx of transactions) {
    console.log('Processing:', tx.id, tx.description);
    const result = processTransaction(tx);
    console.log('Result:', result);
  }
}
```

### Step 2: Compare Working vs Failing Cases

```typescript
// Identify what's different between working and failing cases
const workingCases = data.filter(d => processSuccessfully(d));
const failingCases = data.filter(d => !processSuccessfully(d));

console.log('Working cases:', workingCases.length);
console.log('Failing cases:', failingCases.length);

// Analyze differences
console.log('\n=== Working case sample ===');
console.log(JSON.stringify(workingCases[0], null, 2));

console.log('\n=== Failing case sample ===');
console.log(JSON.stringify(failingCases[0], null, 2));

// Look for patterns
const workingTypes = new Set(workingCases.map(d => typeof d.value));
const failingTypes = new Set(failingCases.map(d => typeof d.value));
console.log('Working value types:', [...workingTypes]);
console.log('Failing value types:', [...failingTypes]);
```

### Step 3: Check for Edge Case Values

```typescript
function analyzeData(items: any[]) {
  const analysis = {
    total: items.length,
    nullValues: 0,
    undefinedValues: 0,
    emptyStrings: 0,
    zeros: 0,
    negatives: 0,
    infinities: 0,
    nans: 0,
    veryLarge: 0,
    verySmall: 0,
    specialChars: 0,
  };

  for (const item of items) {
    for (const [key, value] of Object.entries(item)) {
      if (value === null) analysis.nullValues++;
      if (value === undefined) analysis.undefinedValues++;
      if (value === '') analysis.emptyStrings++;
      if (value === 0) analysis.zeros++;
      if (typeof value === 'number' && value < 0) analysis.negatives++;
      if (value === Infinity || value === -Infinity) analysis.infinities++;
      if (Number.isNaN(value)) analysis.nans++;
      if (typeof value === 'number' && Math.abs(value) > 1e10) analysis.veryLarge++;
      if (typeof value === 'number' && Math.abs(value) < 1e-10 && value !== 0) analysis.verySmall++;
      if (typeof value === 'string' && /[^\x00-\x7F]/.test(value)) analysis.specialChars++;
    }
  }

  return analysis;
}

console.log('Data analysis:', analyzeData(failingCases));
```

### Step 4: Test Boundaries

```typescript
// Test with boundary values
const testCases = [
  { name: 'empty array', value: [] },
  { name: 'single item', value: [1] },
  { name: 'zero', value: 0 },
  { name: 'negative', value: -1 },
  { name: 'empty string', value: '' },
  { name: 'null', value: null },
  { name: 'undefined', value: undefined },
  { name: 'max safe int', value: Number.MAX_SAFE_INTEGER },
  { name: 'infinity', value: Infinity },
  { name: 'NaN', value: NaN },
  { name: 'unicode', value: '日本語🎉' },
  { name: 'whitespace only', value: '   ' },
];

for (const tc of testCases) {
  try {
    const result = processValue(tc.value);
    console.log(`${tc.name}: OK - ${result}`);
  } catch (error) {
    console.log(`${tc.name}: FAIL - ${error.message}`);
  }
}
```

## Real Example: Transfer Detection False Positives

**Symptom**: Transfer detection matched 114 transactions but only 81 were actual transfers

**Diagnosis**:
```typescript
// Compare matched vs unmatched
const matched = candidates.filter(c => hasMatchingPair(c));
const unmatched = candidates.filter(c => !hasMatchingPair(c));

console.log('Matched:', matched.length);
console.log('Unmatched:', unmatched.length);

// Inspect unmatched
for (const tx of unmatched.slice(0, 10)) {
  console.log(`$${tx.amount} | ${tx.description}`);
  // Check why it matched as "transfer candidate"
  console.log(`  Matched keyword: ${findMatchingKeyword(tx.description)}`);
}
```

**Finding**: Transactions like "UBER *LIME... APPLE PAY" were matching because "APPLE" fuzzy-matched "APPLE CARD"

**Root cause**: Keyword matching was too loose

## Common Data Issues and Fixes

| Issue | Detection | Fix |
|-------|-----------|-----|
| Null/undefined | `value == null` | Provide defaults, validate early |
| Empty strings | `value === ''` | Treat as null or validate |
| NaN | `Number.isNaN(value)` | Validate numeric conversions |
| Infinity | `!Number.isFinite(value)` | Clamp to max value |
| Wrong type | `typeof value !== 'expected'` | Explicit type conversion |
| Unicode | `/[^\x00-\x7F]/.test(str)` | Normalize strings |
| Scale | `array.length > threshold` | Add pagination/batching |

## Data Validation Pattern

```typescript
function validateTransaction(tx: unknown): Transaction {
  if (!tx || typeof tx !== 'object') {
    throw new Error('Transaction must be an object');
  }

  const t = tx as Record<string, unknown>;

  if (typeof t.amount !== 'number' || !Number.isFinite(t.amount)) {
    throw new Error(`Invalid amount: ${t.amount}`);
  }

  if (typeof t.description !== 'string') {
    throw new Error(`Invalid description type: ${typeof t.description}`);
  }

  if (!(t.date instanceof Date) && typeof t.date !== 'string') {
    throw new Error(`Invalid date type: ${typeof t.date}`);
  }

  return {
    amount: t.amount,
    description: t.description,
    date: new Date(t.date as string | Date),
  };
}
```
