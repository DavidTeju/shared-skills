# Multi-Agent Orchestration Guide

A reusable system for coordinating multiple Claude agents on parallel implementation work.

---

## Overview

This guide provides templates and strategies for:

1. Analyzing task dependencies to identify parallelizable paths
2. Generating agent prompts with proper coordination instructions
3. Creating coordination documents for real-time status tracking
4. Efficient polling/sleeping patterns to minimize context bloat

---

## Step 1: Dependency Analysis

Before generating prompts, analyze `docs/PHASEx_TASKS.md` to identify:

### 1.1 Build the Dependency Graph

Extract the dependency structure from the tasks file. Example:

```
Epic 1 ──► Epic 2 ──► Epic 3
   │                    │
   │                    ▼
   └──────────────► Epic 4
                        │
            ┌───────────┼───────────┐
            ▼           ▼           ▼
        Epic 5      Epic 6      Epic 7
            │
            ▼
        Epic 8
```

### 1.2 Identify Critical Path

The critical path is the longest chain of dependent work. [Lead] gets critical path epics.

### 1.3 Identify Parallel Paths

Find epics that can run concurrently after their blockers complete. This determines agent count.

### 1.4 Determine Agent Count

**Formula**: `agents = min(max_parallel_paths, 4)`

Agent count is based on **parallelism**, not predefined roles.

### 1.5 Verify Dependencies

**CRITICAL**: Before generating prompts, verify each dependency with the user:

```markdown
| Epic | Depends On | What It Needs           | Verified? |
| ---- | ---------- | ----------------------- | --------- |
| 2    | 1          | Schema exists           | ✅        |
| 3    | 1, 2       | Services + types exist  | ✅        |
| 4    | 1          | Models exist            | ✅        |
| 5    | 4          | Calculations available  | ✅        |
```

---

## Step 2: Assign Epics to Agents

### 2.1 Assignment Strategy

Assign based on the dependency graph:

- **[Lead]**: Gets critical path epics (the blocking work)
- **Other agents**: Get epics that can run in parallel once unblocked

### 2.2 Epic Assignment Matrix

```markdown
| Agent  | Epics   | Blocked By                    |
| ------ | ------- | ----------------------------- |
| [Lead] | X, Y    | -                             |
| [Name] | A, B    | [Lead]'s go-ahead             |
| [Name] | C, D    | [Lead]'s go-ahead + Epic Y    |
```

---

## Step 3: Generate Implementation Prompt

### 3.1 Prompt Template

```markdown
# Phase X Implementation Prompt

## Context

Implementing Phase X ([Phase Name]) for [Project]. [N] agents work in parallel,
coordinating via `docs/PHASEX_COORDINATION.md`.

## Required Reading

1. `docs/ARCHITECTURE.md` - Tech stack, patterns, data models
2. `docs/SPEC.md` - Product requirements, user context
3. `docs/PHASEX_TASKS.md` - Task breakdown with acceptance criteria
4. `docs/PHASEX_COORDINATION.md` - Shared state for coordination

---

## Agents & Dependencies

| Agent  | Epics   | Blocked By                 |
| ------ | ------- | -------------------------- |
| [Lead] | X, Y    | -                          |
| [Name] | A, B    | [Lead]'s go-ahead          |
| [Name] | C, D    | [Lead]'s go-ahead + Epic Y |

---

## Coordination Strategy

**[Lead]**:

- Starts immediately
- Uses AskUserQuestion to clarify ambiguities for ALL epics
- Logs answers in Questions table
- Posts "GO - all questions answered" in Messages when ready
- Begins work on their epics

**All other agents**:

- Poll coordination doc for [Lead]'s "GO" message FIRST
- THEN check if their specific blockers show ✅
- Only start work when BOTH conditions are met
- If questions arise mid-flight, add to Messages section

**All agents**:

- Update Status table immediately when starting (🔄) or completing (✅)
- Log files created in Work Log
- Log any spec deviations in Decisions table

---

## Notes

- Follow existing patterns in `src/features/` and `src/lib/trpc/routers/`
- [Phase-specific constraints]
- [Out-of-scope items]
```

---

## Step 4: Generate Coordination Document

### 4.1 Coordination Doc Template

```markdown
# Phase X Coordination

---

## Status

| Epic | Agent  | Status | Blocker |
| ---- | ------ | ------ | ------- |
| 1    | [Lead] | ⏳     | -       |
| 2    | [Lead] | ⏳     | -       |
| 3    | [Name] | ⏳     | GO + Epic 1 |
| 4    | [Name] | ⏳     | GO + Epic 2 |

`⏳` = Waiting | `🔄` = In Progress | `✅` = Done | `❌` = Failed

---

## Questions ([Lead] populates, [Owner] answers)

_[Lead]: Add any questions here before starting. [Owner] will answer._
_Other agents: Add questions via Messages below._

| Q#  | Question | Answer |
| --- | -------- | ------ |
|     |          |        |

---

## Messages

_Agent-to-agent communication. Include your name and timestamp._

```
[YYYY-MM-DD HH:MM] [Lead]: GO - all questions answered. @[Name] @[Name] you may begin polling your blockers.
```

---

## Work Log

### [Lead]

**Epic X**: ⏳ Waiting

### [Name]

**Epic A**: ⏳ Waiting (blocked by GO + Epic X)

---

## Decisions

| Agent | Epic | Decision |
| ----- | ---- | -------- |
|       |      |          |
```

---

## Step 5: Polling & Sleep Strategies

### 5.1 Wait for GO + Blockers (for starting work)

Use when waiting to begin work on assigned epics:

```bash
COORD_FILE="docs/PHASEX_COORDINATION.md"
LAST_MTIME=""

while true; do
  CURRENT_MTIME=$(stat -f %m "$COORD_FILE" 2>/dev/null || stat -c %Y "$COORD_FILE")

  if [ "$CURRENT_MTIME" != "$LAST_MTIME" ]; then
    if grep -q "GO.*all questions answered" "$COORD_FILE"; then
      if grep -q "Epic X.*✅" "$COORD_FILE"; then
        echo "UNBLOCKED"
        break
      fi
    fi
    LAST_MTIME="$CURRENT_MTIME"
  fi

  sleep 60
done
```

### 5.2 Wait for ANY Update (for mid-work questions)

Use when you post a question/message and need to wait for a response:

```bash
COORD_FILE="docs/PHASEX_COORDINATION.md"
LAST_MTIME=$(stat -f %m "$COORD_FILE" 2>/dev/null || stat -c %Y "$COORD_FILE")

echo "Waiting for any update to coordination file..."
while true; do
  sleep 60
  CURRENT_MTIME=$(stat -f %m "$COORD_FILE" 2>/dev/null || stat -c %Y "$COORD_FILE")

  if [ "$CURRENT_MTIME" != "$LAST_MTIME" ]; then
    echo "File updated - checking for response"
    break
  fi
done
```

**When to use this:**
- You posted a question in Messages and need an answer
- You're waiting for clarification from another agent
- You need to know when any coordination activity happens

### 5.3 Alternative: Simple Grep Loops

```bash
# Wait for GO signal first
while ! grep -q "GO.*all questions answered" "$COORD_FILE"; do
  sleep 60
done

# Then wait for specific blocker
while ! grep -q "Epic X.*✅" "$COORD_FILE"; do
  sleep 60
done
echo "UNBLOCKED"
```

### 5.3 Anti-Pattern: Subagent Busy Work

**DON'T DO THIS**:

```
While waiting, spawn subagent to "explore the codebase"
```

**Why it's bad**:

- Wastes tokens on exploration that may be invalidated
- Files may change while reading (stale understanding)
- No clear termination condition

### 5.4 Good Pattern: Targeted Preparation

**DO THIS** while blocked:

```
1. Read STABLE files only:
   - docs/ARCHITECTURE.md (won't change)
   - docs/SPEC.md (won't change)
   - Existing patterns in src/features/*/services/*.ts

2. DON'T read:
   - Files the blocking agent is actively creating/modifying
   - Any file listed in the blocker's Work Log as "in progress"
```

### 5.5 Sleep Duration Recommendations

| Context                | Sleep Duration | Rationale              |
| ---------------------- | -------------- | ---------------------- |
| Early in blocking work | 5-10 minutes   | Blocker just started   |
| Mid-way through        | 2-5 minutes    | Progress expected      |
| Near completion        | 30-60 seconds  | Quick detection needed |

---

## Step 6: Context Bloat Prevention

### 6.1 Keep Agent Prompts Minimal

- Reference docs by path, don't inline content
- Coordination doc should be <100 lines
- Use structured tables, not prose

### 6.2 Work Log Best Practices

**Good**:

```
- Created features/budget/services/validation.ts
- Implemented validateBudgetItems() with 5 rules
- 16 tests passing
```

**Bad**:

```
- Created a new file at features/budget/services/validation.ts that contains
  the validateBudgetItems function which takes an array of budget items and
  returns a ValidationResult object containing...
[500 words of description]
```

### 6.3 Message Efficiency

**Good**:

```
[10:15] [Lead]: Epic 1 complete. Files: validation.ts, budget.ts. @[Name] unblocked.
```

**Bad**:

```
[10:15] [Lead]: I have finished working on Epic 1. The files I created are...
[followed by detailed descriptions]
```

---

## Step 7: Execution Checklist

Before launching agents:

- [ ] Dependencies verified in PHASEX_TASKS.md
- [ ] Agent count based on parallelism
- [ ] Each agent has clear epic assignments
- [ ] Coordination doc created with empty status table
- [ ] [Lead] knows to ask questions first and post GO when ready

During execution:

- [ ] [Lead] asks questions BEFORE starting work
- [ ] [Lead] posts GO message after questions answered
- [ ] Other agents wait for GO + their specific blockers
- [ ] All agents update status immediately on state changes
- [ ] Files created logged in Work Log

After completion:

- [ ] All epics marked ✅
- [ ] Work logs complete
- [ ] Decisions documented
- [ ] Tests passing
- [ ] ARCHITECTURE.md updated if needed

---

## CRITICAL: Agent Naming Rules

**Agents MUST have human names.** This is non-negotiable.

**Why human names?**

1. **Grep-friendly**: `grep "[Name]"` works cleanly
2. **Readable logs**: `[Name]: Epic 1 complete` is natural
3. **Natural coordination**: "@[Name] you're unblocked" feels like team communication

**Good names** (short, distinct, easy to type):

- Tom, Dan, Mary, Sue, Bob, Pam, Joe, Kim, Max, Zoe

**Bad names** (avoid these):

- Agent1, AgentA, Worker1 (not human, hard to grep)
- Dan/Don, Tom/Tim (too similar, easy to confuse)
- Alexander, Christopher (too long to type repeatedly)

---

## Template Files

Co-located in this skill folder:

- `IMPLEMENTATION_PROMPT_TEMPLATE.md`
- `COORDINATION_TEMPLATE.md`
