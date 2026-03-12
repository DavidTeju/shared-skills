---
name: code-review
description: |
  Perform a thorough, critical code review of an entire codebase. Use when:
  (1) user asks for a "code review", (2) user wants to find bugs or issues,
  (3) user asks "what's wrong with this code", (4) user wants security audit,
  (5) user asks about edge cases or best practices violations, (6) user asks
  to "find missed tasks" or "what slipped through the cracks". Covers security,
  bugs, edge cases, code quality, deprecated code, readability, best practices,
  and missed task detection. Outputs findings to a markdown file organized by severity.
author: Claude Code
---

# Comprehensive Codebase Code Review

## Purpose

Perform a thorough, critical code review as if reviewing a junior engineer's work.
Assume nothing is correct until verified. Look for bugs, security issues, edge cases,
and violations of best practices.

## Process

### Phase 1: Codebase Exploration

First, understand the codebase structure using the Explore agent:

```
Use Task tool with subagent_type=Explore to understand:
1. Overall architecture and tech stack
2. All source files and their purposes
3. Key dependencies and how they're used
4. Database schema and data flow
5. API endpoints and routing
6. Configuration and environment handling
```

### Phase 2: Critical File Deep Dive

Read these file categories in parallel:

1. **API Routes** - All endpoint handlers
2. **Authentication** - Auth providers, middleware, session handling
3. **Database** - Schema, migrations, queries, ORM usage
4. **State Management** - Stores, context, data flow
5. **Core Business Logic** - Main functionality implementations
6. **Configuration** - package.json, env handling, config files

### Phase 3: Issue Detection

Check for issues in these categories:

#### 1. CRITICAL / SECURITY

- [ ] Authentication bypass possibilities
- [ ] Authorization checks missing (ownership verification)
- [ ] Input sanitization missing (SQL injection, XSS, command injection)
- [ ] Sensitive data exposure (API keys, credentials in code/logs)
- [ ] CORS misconfiguration
- [ ] Rate limiting absent
- [ ] Async operations that lose auth context
- [ ] Insecure direct object references (IDOR)

#### 2. BUGS

- [ ] Validation/guard functions defined but never called
- [ ] Return values in wrong order or format
- [ ] Off-by-one errors, division by zero
- [ ] Race conditions in concurrent operations
- [ ] Memory leaks (event listeners not cleaned up)
- [ ] Promises not awaited
- [ ] Error handling that swallows errors
- [ ] State updates after component unmount
- [ ] Incorrect null/undefined checks

#### 3. EDGE CASES

- [ ] Empty arrays/objects not handled
- [ ] Concurrent operations on same resource
- [ ] Network failures during multi-step operations
- [ ] Maximum limits not enforced (items, depth, size)
- [ ] Timeout handling missing
- [ ] Duplicate data not prevented
- [ ] Orphaned records possible

#### 4. CODE QUALITY

- [ ] Type assertions bypassing type safety (`as Type`)
- [ ] Non-null assertions (the ! operator) hiding potential nulls
- [ ] Duplicate code that should be extracted
- [ ] Inconsistent error handling patterns
- [ ] Magic numbers/strings not in constants
- [ ] Dead code (unused imports, functions, variables)
- [ ] Overly complex functions (>50 lines, deep nesting)

#### 5. DEPRECATED / UNNECESSARY

- [ ] Unused dependencies in package.json
- [ ] Dead code paths never executed
- [ ] Deprecated API usage
- [ ] Libraries with known vulnerabilities
- [ ] Features half-implemented or abandoned

#### 6. READABILITY

- [ ] Missing or misleading comments
- [ ] Inconsistent naming conventions
- [ ] Complex logic without explanation
- [ ] Magic booleans in function signatures
- [ ] Deeply nested ternaries
- [ ] Inline SVGs/styles that should be components
- [ ] No JSDoc on public functions

#### 7. BEST PRACTICES

- [ ] Environment variables not validated at startup
- [ ] No request/response logging
- [ ] No caching headers on API responses
- [ ] Database queries without indexes
- [ ] N+1 query patterns
- [ ] No health check endpoints
- [ ] No graceful degradation

### Phase 4: Output Format

Create a markdown file `CODE_REVIEW.md` with this structure:

```markdown
# Critical Code Review: [Project Name]

## CRITICAL / SECURITY ISSUES

### 1. [Issue Title]

**Location:** `path/to/file.ts:line-number`
**Problem:** [Description with code snippet]
**Impact:** [What could go wrong]

## BUGS

### N. [Issue Title]

...

## EDGE CASES

...

## CODE QUALITY ISSUES

...

## DEPRECATED / UNNECESSARY CODE

...

## CODE READABILITY ISSUES

...

## BEST PRACTICES VIOLATIONS

...

## SUMMARY

| Severity          | Count |
| ----------------- | ----- |
| Critical/Security | X     |
| Bugs              | X     |
| Edge Cases        | X     |
| Code Quality      | X     |
| Deprecated        | X     |
| Readability       | X     |
| Best Practices    | X     |

**Most Urgent Fixes:**

1. ...
2. ...
```

### Phase 5: Open in Editor

After writing the file, open it in VS Code using the `code` command.

## Common Patterns to Flag

### Security

```typescript
// BAD: No ownership check
const node = await db.nodes.findById(nodeId); // Anyone's node!

// GOOD: Verify ownership
const node = await db.nodes.findById(nodeId);
if (node.userId !== currentUser.id) throw new ForbiddenError();
```

### Dead Validation Code

```typescript
// BAD: Validation function exists but is never called
function validateInput(data) { ... }  // Defined but unused
await processData(userInput)  // No validation!

// GOOD: Always use validation before processing
const validated = validateInput(userInput)
await processData(validated)
```

### Type Safety

```typescript
// BAD: Type assertion hides errors
const data = response as UserData; // What if response is different?

// GOOD: Validate at runtime
const data = userDataSchema.parse(response); // Throws if invalid
```

### Error Handling

```typescript
// BAD: Swallowing errors
try {
  await riskyOperation();
} catch (e) {
  console.log(e);
}

// GOOD: Propagate or handle properly
try {
  await riskyOperation();
} catch (e) {
  logger.error({ error: e }, "Operation failed");
  throw new OperationFailedError(e.message);
}
```

## Tone

Be critical but constructive. Assume the code has bugs until proven otherwise.
For each issue:

1. State what's wrong clearly
2. Explain the impact/risk
3. Show the problematic code
4. Suggest a fix when possible

## Notes

- Always read files before criticizing them
- Use line numbers for specific issues
- Group related issues together
- Prioritize security and bugs over style issues
- Check if issues are already tracked in TODO comments
- Consider the project's stage (MVP vs production)

---

## Sub-Skill: Missed Task Detection

Find tasks marked complete in task files but never actually integrated.

### When to Use

- After completing a project phase
- When user says "find missed tasks" or "what slipped through"
- As part of a comprehensive review
- When unused code lint shows many exports

### Process

#### Step 1: Run Unused Code Detection

```bash
npm run lint:unused
# OR if knip is installed:
npx knip
```

#### Step 2: Get Task File

Read the relevant phase task file (e.g., `docs/PHASE1_TASKS.md`, `docs/PHASE2_TASKS.md`)

#### Step 3: Cross-Reference

For each unused export, determine:

1. **Is it a "slipped through" task?** - Component created for a specific task but never hooked up
2. **Is it a false positive?** - Internal helper, API completeness, or barrel export

**Key indicators of slipped-through tasks:**

- Unused UI components (skeletons, empty states, modals)
- Unused hooks (especially `use*Handler` patterns)
- Unused services that correspond to task descriptions
- Components in `common/` or `shared/` folders with no imports

**False positives to ignore:**

- Components used internally by other components (e.g., `StatCardSkeleton` used by `DashboardStatsSkeleton`)
- Type-only exports for external API
- Barrel `index.ts` re-exports
- shadcn/ui or library completeness exports

#### Step 4: Verify Each Candidate

For each potential "slipped through" item:

```bash
# Check if it's used anywhere
grep -r "ComponentName" src/
```

Then read the files that should be using it to confirm the gap.

#### Step 5: Output Report

Create `docs/MISSED_TASKS_ANALYSIS.md` with this structure:

````markdown
# Missed Tasks Analysis - [Phase X]

**Generated:** [Date]

## 🚨 Confirmed Missed Integrations

### 1. [Component/Feature Name]

**Task:** "[Task description from tasks file]" (Section X.X)
**Status:** ❌ Not integrated

| Component       | File                    | Usage          |
| --------------- | ----------------------- | -------------- |
| `ComponentName` | `path/to/file.tsx:line` | **Never used** |

**Current State:** [What the code does instead]
**Fix:** [What needs to change]

---

## ✅ Correctly Integrated Components

| Component | Used In |
| --------- | ------- |
| ...       | ...     |

## 📦 False Positives (OK to be "unused")

| Item | Reason |
| ---- | ------ |
| ...  | ...    |

## 📋 Summary Action Items

| Priority  | Item | Effort |
| --------- | ---- | ------ |
| 🔴 High   | ...  | X min  |
| 🟡 Medium | ...  | X min  |
| 🟢 Low    | ...  | X min  |

## Verification Command

```bash
npm run lint:unused | grep -E "Component1|Component2|..."
```
````

```

### Common Patterns (not exhaustive)

**Loading states created but not used:**
- Skeleton components exist but pages use inline `<Loader2>` spinners
- Look for: `*Skeleton` exports that aren't imported

**Empty states created but not used:**
- `NoX` components exist but pages render inline empty divs
- Look for: `No*`, `Empty*` exports that aren't imported

**Hooks created but not used:**
- `useErrorHandler`, `useFormValidation` etc. defined but never called
- Look for: `use*` exports with 0 imports

**Services created but not called:**
- Utility functions in `services/` folders never imported
- Look for: service files with no consumers
```
