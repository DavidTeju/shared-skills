---
name: bug-basher-5000
description: |
  Find real, user-impacting bugs across an entire codebase using a swarm of specialized agents.
  Use when: (1) user invokes /bug-basher or /bug-basher-5000, (2) user asks to "find bugs",
  "hunt for bugs", or "what's broken", (3) user wants a bug audit focused on UX impact.
  NOT for code reviews or style nits. Focuses exclusively on: crashes, data corruption,
  confusing UX, broken features, bad error messages, logical inconsistencies. Uses parallel
  agents that scale with codebase size (3-25 agents). Outputs BUGS_FOUND.md organized by
  severity with quick wins surfaced first. Agents perform root cause analysis for each bug.
author: Claude Code---

# Bug Basher 5000

Find real, user-impacting bugs across an entire codebase using a swarm of specialized agents.

## Trigger

Use when:

- User invokes `/bug-basher` or `/bug-basher-5000`
- User asks to "find bugs", "hunt for bugs", "what's broken"
- User wants a bug audit (NOT a code review - that's different)

## Philosophy: Real Bugs Only

This skill finds bugs that **hurt real users**. It explicitly avoids:

- ❌ Code style/formatting issues
- ❌ Minor TypeScript strictness ("could use `as const`", "prefer interface")
- ❌ Micro-optimizations that won't noticeably affect users
- ❌ "Best practice" suggestions that don't fix actual problems
- ❌ Theoretical security issues that require unlikely attack vectors

Focus exclusively on:

- ✅ Things that crash, error, or break functionality
- ✅ Things that corrupt or lose user data
- ✅ Things that confuse users (bad error messages, broken flows)
- ✅ Things that degrade the user experience noticeably
- ✅ Logical inconsistencies that produce wrong results

## Execution Protocol

### Phase 1: Context Gathering

1. **Infer application context automatically:**
   - Read `README.md`, `ARCHITECTURE.md`, `package.json`
   - Identify the tech stack (Next.js, React, database, etc.)
   - Understand what the app does and who uses it

2. **Ask targeted clarifying questions** if unclear:
   - What are the 3-5 most critical user flows?
   - Any known problem areas or recent regressions?
   - Any flows involving money, auth, or sensitive data?

### Phase 2: Codebase Analysis & Agent Planning

1. **Map the codebase structure:**

   ```
   - Count features/modules
   - Identify user-facing entry points (pages, API routes)
   - Find critical paths (auth, payments, data mutations)
   ```

2. **Plan agent swarm** (scale with codebase size):

   **User Flow Agents** (trace full vertical slice: UI → API → Service → DB → Response):
   - One agent per critical user flow identified
   - Each traces the complete path a user action takes

   **Feature Agents:**
   - One agent per major feature directory
   - Focuses on internal consistency within the feature

   **Cross-Cutting Agents:**
   - Error handling patterns across the codebase
   - Data validation at system boundaries
   - State management and data flow consistency

3. **Intentional overlap:** Agents should have overlapping scopes. If two agents find the same bug, it's higher confidence and their perspectives get merged.

### Phase 3: Parallel Bug Hunting

Launch all agents in parallel using the Task tool. Each agent receives:

```markdown
## Agent Assignment: [Agent Name]

### Scope

[Specific files/flows this agent owns]

### Shared Context

[Key types, utils, schema that all agents need]

### Hunt For These Bug Categories

**Error Handling Gaps:**

- Unhandled promise rejections
- Missing try/catch around async operations
- Errors that show stack traces or technical jargon to users
- API errors that don't inform the user what went wrong
- Failed operations that don't rollback or cleanup

**State Inconsistencies:**

- Race conditions between concurrent operations
- Stale data after mutations (missing invalidation)
- Optimistic updates that don't rollback on failure
- Inconsistent state between client and server

**Input Validation Holes:**

- Missing validation on user input
- Malformed data that crashes instead of showing helpful errors
- Edge cases: empty strings, null, undefined, negative numbers, zero
- Boundary conditions: max lengths, date ranges, amount limits

**Edge Case Failures:**

- Empty arrays/lists not handled
- First-time user scenarios (no data yet)
- Deleted/missing referenced data
- Concurrent modification conflicts

**UI/UX Bugs:**

- Loading states missing or broken
- Error states that don't guide the user
- Forms that lose data on error
- Navigation that breaks or loses context
- Accessibility issues that prevent usage

**Data Integrity Issues:**

- Operations that can leave data in inconsistent state
- Missing foreign key handling (orphaned records)
- Calculations that can produce wrong results
- Timezone or date handling bugs

### Output Format

For each bug found, provide:

1. **Location:** file:line_number
2. **Bug:** One-sentence description
3. **Root Cause:** WHY does this bug exist? (See Root Cause Analysis Guide below)
4. **Impact:** How this affects users
5. **Reproduction:** Context for when this triggers
6. **Suggested Fix(es):** One or more approaches to resolve
7. **Effort:** Quick Fix | Moderate | Complex

### Effort Level Guide

**IMPORTANT:** "Quick Fix" means low complexity, NOT a band-aid or patch. All fixes should be proper solutions that address the root cause.

| Effort | Meaning | Examples |
|--------|---------|----------|
| **Quick Fix** | Simple, localized change. Can be fixed in <15 minutes with confidence. | Swap two color values, add missing `null` check, change `publicProcedure` to `protectedProcedure`, add query invalidation |
| **Moderate** | Requires understanding context or touching multiple files. 15-60 minutes. | Add new validation logic, refactor a function, fix a calculation formula, add error handling path |
| **Complex** | Architectural change, schema migration, or cross-cutting concern. 1+ hours. | Remove duplicate source of truth, redesign data flow, add new infrastructure |

**Quick Fix does NOT mean:**
- ❌ A hacky workaround that masks the symptom
- ❌ A temporary patch that needs revisiting
- ❌ Ignoring the root cause
- ❌ Adding a comment like `// TODO: fix properly later`

**Quick Fix DOES mean:**
- ✅ The actual fix is simple and correct
- ✅ The root cause is addressed, not worked around
- ✅ No technical debt introduced
- ✅ Just happens to be a small change

### Root Cause Analysis Guide

For each bug, dig deeper to understand WHY it exists. Good root cause analysis:

**Categories of Root Causes:**

1. **Missing Knowledge** - Developer didn't know about an API behavior, edge case, or constraint
   - Example: "Didn't know httpOnly cookies can't be read by JavaScript"
   - Example: "Unaware that parseISO() doesn't handle RFC 2822 dates"

2. **Incorrect Assumption** - Code assumes something that isn't always true
   - Example: "Assumes array will always have elements"
   - Example: "Assumes user will always have linked accounts"

3. **Incomplete Implementation** - Feature was partially built
   - Example: "Handled the success case but not the error case"
   - Example: "Added validation to single update but not bulk update"

4. **Schema/Architecture Issue** - The design itself is flawed
   - Example: "Dual source of truth between Receipt.transactionId and ReceiptMatch.transactionId"
   - Example: "In-memory storage loses data on restart"

5. **Copy-Paste Error** - Code was duplicated and one copy diverged
   - Example: "Color logic was inverted when copying from another component"

6. **Timing/Ordering Issue** - Operations happen in wrong sequence
   - Example: "State read before async update completes"
   - Example: "Cache invalidation happens before mutation finishes"

7. **Integration Gap** - Two systems don't communicate correctly
   - Example: "OAuth callback doesn't verify session exists"
   - Example: "Cron job doesn't know about sync window limits"

**Root Cause Format:**

```
Root Cause: [Category] - [Specific explanation]
```

Examples:
- "Root Cause: Incorrect Assumption - Code assumes `document.cookie` can read all cookies, but httpOnly cookies are intentionally hidden from JavaScript for security"
- "Root Cause: Schema Issue - Two fields (Receipt.transactionId and ReceiptMatch.transactionId) both store the same relationship, requiring manual synchronization that frequently fails"
- "Root Cause: Missing Knowledge - European locales use comma as decimal separator (1.234,56 = 1234.56), but parser treats comma as thousands separator"

### NOT Bugs (Ignore These)

- Code style preferences
- "Could be cleaner" refactoring
- TypeScript strictness suggestions
- Performance micro-optimizations
- Theoretical issues requiring unlikely scenarios
```

### Phase 4: Merge & Deduplicate

1. Collect all agent findings
2. Merge duplicates found by multiple agents:
   - Combine their contexts and perspectives
   - Merge root cause analyses for richer understanding
   - Note "Found by X agents" as confidence indicator
3. Classify by severity:
   - **Critical:** Data loss, security breach, completely broken features
   - **High:** Features that don't work, major UX degradation
   - **Medium:** Degraded UX, confusing behavior, unreliable features
   - **Low:** Minor annoyances, edge cases with workarounds

4. Within each severity tier, sort by effort (Quick Fix first). Remember: Quick Fix = low complexity proper fix, not a band-aid.

5. **Group by root cause pattern:** If multiple bugs share the same root cause category, note this pattern for systemic fixes

### Phase 5: Generate Report

Create `BUGS_FOUND.md` with this structure:

```markdown
# Bug Basher 5000 Report

**Project:** [name]
**Scanned:** [date]
**Files Analyzed:** [count]
**Agents Deployed:** [count]

## Summary

- Critical: X bugs
- High: X bugs
- Medium: X bugs
- Low: X bugs
- **Total:** X bugs

## Root Cause Patterns

[Identify systemic issues - e.g., "5 bugs stem from dual source of truth in schema"]

| Root Cause Category | Bug Count | Examples |
|---------------------|-----------|----------|
| Schema/Architecture | 5 | BUG-001, BUG-003, BUG-007 |
| Missing Validation | 4 | BUG-002, BUG-005 |
| Incorrect Assumption | 3 | BUG-004, BUG-006 |

## Quick Wins

[Bugs from any severity that are Quick Fix effort - tackle these first!]

---

## Critical Bugs

### [BUG-001] [Short title]

**Location:** `src/features/auth/services/login.ts:142`
**Impact:** [User-facing consequence]
**Reproduction:** [When/how this triggers]

**The Bug:**
[Detailed explanation]

**Root Cause:** [Category] - [Specific explanation of WHY this bug exists]

**Suggested Fixes:**

1. [Approach one]
2. [Approach two, three or four if applicable]

**Effort:** Quick Fix | Moderate | Complex
**Confidence:** Found by 2 agents

---

## High Bugs

[Same format...]

## Medium Bugs

[Same format...]

## Low Bugs

[Same format...]

## Systemic Recommendations

Based on root cause patterns, consider these architectural improvements:

1. [Recommendation based on common root causes]
2. [Recommendation based on common root causes]
```

Open the file in VS Code when complete.

## Scaling Rules

- **Small codebase (<50 files):** 3-5 agents
- **Medium codebase (50-200 files):** 6-10 agents
- **Large codebase (200-500 files):** 10-15 agents
- **Very large codebase (500+ files):** 15-25 agents, chunked scanning

Each agent should be able to complete its scope within context limits. If a scope is too large, split into sub-agents.

## Example Agent Prompts

**User Flow Agent - Transaction Import:**

```
Trace the complete user flow for importing transactions:
1. UI: CSV upload component → validation → preview
2. API: Import endpoint → parsing → transformation
3. Service: Duplicate detection → categorization → persistence
4. Response: Success/error handling → UI update

Hunt for bugs at each step and across transitions.
For each bug, identify the root cause - WHY does this bug exist?
```

**Feature Agent - Budget Module:**

```
Analyze src/features/budget/ for bugs:
- Components: state management, user input handling
- Services: calculations, data fetching, mutations
- Integration: how it connects to transactions, categories

Focus on calculation accuracy and data consistency.
For each bug, perform root cause analysis to understand the underlying issue.
```

**Cross-Cutting Agent - Error Handling:**

```
Scan all API routes and services for:
- Unhandled promise rejections
- Missing try/catch
- Errors that expose internals to users
- Failed operations without proper cleanup

Document root causes - are these missing knowledge, incomplete implementation, or architectural gaps?
```

## Verification

The skill executed successfully when:

1. **Report generated:** `BUGS_FOUND.md` exists and opened in VS Code
2. **Real bugs found:** Findings describe actual user-impacting issues, not style nits
3. **Actionable output:** Each bug has location, impact, root cause, and suggested fixes
4. **Root causes documented:** Each bug explains WHY it exists, not just what it is
5. **Patterns identified:** Report surfaces systemic issues from common root causes
6. **Quick wins surfaced:** Easy fixes are prominently displayed regardless of severity
7. **No false positives:** Bugs are verifiable by tracing the code path described

**Signs of failure:**
- Report is full of style/formatting suggestions
- Bugs lack file:line locations
- No root cause analysis provided
- Root causes are superficial ("bug exists because code is wrong")
- No suggested fixes provided
- Theoretical issues without real-world trigger conditions
- Agents timed out or failed to complete their scopes

## Notes

**Caveats:**
- Effectiveness depends on code readability; heavily obfuscated code reduces accuracy
- May miss bugs in generated code, node_modules, or vendored dependencies (by design)
- Agent count is a guideline; adjust based on codebase complexity, not just file count

**Edge cases:**
- Monorepos: Treat each package as a separate codebase for agent planning
- Very large files (>1000 lines): May need dedicated sub-agents per file
- Legacy code: Lower the bar for "Quick Fix" since even small improvements help

**When NOT to use this skill:**
- For style/formatting cleanup (use linters)
- For security audits requiring threat modeling (use dedicated security review)

**Relationship to other skills:**
- `code-review`: Broader scope, includes style and best practices. Use bug-basher when you want focused, actionable bug fixes only.
- `claudeception`: If bug-basher discovers a pattern of bugs unique to this codebase, consider extracting a skill for prevention.
