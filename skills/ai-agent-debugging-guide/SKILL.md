---
name: ai-agent-debugging-guide
description: |
  Comprehensive debugging guide for AI agents tackling confusing issues. Use when:
  (1) code hangs/freezes with no error, (2) behavior differs from expectations with no clear cause,
  (3) errors are misleading or don't point to root cause, (4) you've tried obvious fixes and they
  didn't work, (5) the issue only reproduces in certain conditions. Contains strategies for:
  silent hangs, misleading errors, data-dependent bugs, race conditions, and integration issues.
  Core principle: CREATE OBSERVABILITY before attempting fixes.
author: Claude Code
user-invocable: false
---

# AI Agent Debugging Guide

## Core Philosophy

**Don't guess - observe.** The #1 mistake AI agents make when debugging is attempting fixes
before understanding what's actually happening. Create observability first, then diagnose.

## When to Use This Guide

Activate this debugging guide when you encounter:

1. **Silent failures**: Code hangs, returns wrong results, or does nothing - with no error
2. **Misleading errors**: Error message points to wrong location or cause
3. **Intermittent issues**: Works sometimes, fails others
4. **Complex systems**: Multiple services, async operations, or third-party libraries
5. **"It should work"**: Logic looks correct but behavior is wrong

## The Debug Script Strategy (Primary Technique)

When code behaves unexpectedly, **create a standalone debug script** that:
1. Reproduces the issue in isolation
2. Has extensive logging at every step
3. Uses real data from the system
4. Runs outside the main application

### Why This Works

- **Isolation**: Removes framework complexity, middleware, caching
- **Observability**: You control exactly what gets logged
- **Reproducibility**: Same script, same results - easy to iterate
- **Speed**: Faster iteration than running full app

### Template: Debug Script Structure

```typescript
#!/usr/bin/env npx tsx
/**
 * Debug Script: [WHAT YOU'RE DEBUGGING]
 *
 * Usage: npx tsx scripts/debug-[issue-name].ts
 */

import 'dotenv/config';  // Load env vars

// ANSI colors for readable output
const CYAN = '\x1b[36m';
const GREEN = '\x1b[32m';
const YELLOW = '\x1b[33m';
const RED = '\x1b[31m';
const DIM = '\x1b[2m';
const RESET = '\x1b[0m';

async function main() {
  console.log(`\n${CYAN}═══════════════════════════════════════════${RESET}`);
  console.log(`${CYAN}  DEBUG: [Issue Name]${RESET}`);
  console.log(`${CYAN}═══════════════════════════════════════════${RESET}\n`);

  // STEP 1: Fetch real data
  console.log(`${YELLOW}[STEP 1] Fetching data...${RESET}`);
  const data = await fetchRealData();
  console.log(`  Found ${data.length} items`);

  // STEP 2: Transform/process with logging
  console.log(`\n${YELLOW}[STEP 2] Processing...${RESET}`);
  for (let i = 0; i < data.length; i++) {
    console.log(`  Processing ${i + 1}/${data.length}...`);

    // Log inputs
    console.log(`    Input: ${JSON.stringify(data[i]).slice(0, 100)}`);

    // Do the operation
    const result = await processItem(data[i]);

    // Log outputs
    console.log(`    Output: ${JSON.stringify(result).slice(0, 100)}`);
  }

  // STEP 3: Summarize findings
  console.log(`\n${CYAN}═══════════════════════════════════════════${RESET}`);
  console.log(`${CYAN}  RESULTS${RESET}`);
  console.log(`${CYAN}═══════════════════════════════════════════${RESET}\n`);

  // Print summary statistics
}

main().catch(console.error);
```

### Key Logging Points

Add console.log statements:

1. **Before and after every external call** (DB, API, library)
2. **At loop boundaries** (start, each iteration, end)
3. **At decision points** (if/else branches taken)
4. **For intermediate values** (especially computed/transformed data)
5. **For timing** (when operations might be slow)

### Real Example: Silent Hang Diagnosis

We had code that called a library function (`munkres()`) that would hang with no error.
The debug script approach revealed:

```typescript
// Added logging around the suspicious call
console.log(`  Processing bucket ${i}/${total}...`);
console.log(`    Matrix size: ${matrix.length}x${matrix[0]?.length}`);
console.log(`    Running munkres...`);

const result = munkres(matrix);  // <-- HANGS HERE

console.log(`    Got ${result.length} assignments`);  // Never printed!
```

The logging showed us exactly which bucket caused the hang, and inspection of that
bucket's matrix revealed `Infinity` values that broke the algorithm.

## Strategy Index

See the `strategies/` subdirectory for specific debugging techniques:

| Strategy | Use When |
|----------|----------|
| [silent-hang.md](strategies/silent-hang.md) | Code freezes with no error |
| [misleading-error.md](strategies/misleading-error.md) | Error points to wrong cause |
| [data-dependent.md](strategies/data-dependent.md) | Works with some data, fails with others |
| [async-race.md](strategies/async-race.md) | Intermittent failures, timing issues |
| [integration.md](strategies/integration.md) | Third-party library or API issues |

## Quick Reference: Debugging Checklist

When stuck, work through this checklist:

### 1. Reproduce Reliably
- [ ] Can you trigger the bug consistently?
- [ ] What's the minimal reproduction case?
- [ ] Does it happen with all data or specific data?

### 2. Create Observability
- [ ] Created a debug script with extensive logging?
- [ ] Logging BEFORE and AFTER the suspected problem area?
- [ ] Logging intermediate values and state?

### 3. Isolate the Problem
- [ ] Narrowed down to specific function/line?
- [ ] Tested that function with controlled inputs?
- [ ] Confirmed the issue is in YOUR code vs library/framework?

### 4. Form Hypothesis
- [ ] What specifically do you think is wrong?
- [ ] How would you verify this hypothesis?
- [ ] What would you expect to see if hypothesis is correct?

### 5. Test Fix
- [ ] Does the fix address root cause or just symptom?
- [ ] Run existing tests - any regressions?
- [ ] Does debug script now produce expected output?

## Anti-Patterns to Avoid

### 1. Guessing Without Observing
**Bad**: "Maybe if I change this parameter..."
**Good**: "Let me add logging to see what value this parameter has"

### 2. Fixing Symptoms
**Bad**: Adding try/catch around a failing call without understanding why it fails
**Good**: Understanding the failure, then deciding how to handle it

### 3. Assuming the Error Message is Right
**Bad**: "The error says 'undefined is not a function' so something is undefined"
**Good**: "Let me trace the actual call stack to see what's really happening"

### 4. One Change at a Time? (It Depends)
**Good for production**: Make one change, verify, repeat
**Good for debugging**: Add LOTS of logging at once to get full picture

### 5. Not Using Real Data
**Bad**: "Works with my test case [1, 2, 3]"
**Good**: "Let me pull actual data from the database and run through it"

## When to Escalate

If after applying these strategies you're still stuck:

1. **Time-box**: Set a limit (e.g., 30 mins) before escalating
2. **Document findings**: Write what you've tried and observed
3. **Ask user**: "I've narrowed it down to X but need help understanding Y"
4. **Search**: Check GitHub issues, Stack Overflow for similar problems

## Notes for AI Agents

- **Create scripts liberally**: Don't hesitate to create temporary debug scripts
- **Log verbosely**: More logging is almost always better during debugging
- **Trust the data**: What you observe > what you expect
- **Clean up after**: Remove or comment out debug logging when done
- **Save learnings**: If you discover something non-obvious, create/update a skill
