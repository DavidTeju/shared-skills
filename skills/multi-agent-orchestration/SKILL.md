---
name: multi-agent-orchestration
description: |
  Set up multi-agent parallel implementation for a project phase. Use when:
  (1) user has a PHASEx_TASKS.md with multiple epics and dependencies,
  (2) user wants to parallelize work across multiple Claude agents,
  (3) user asks to "set up orchestration" or "coordinate agents" for a phase.
  Analyzes dependencies, determines agent count, generates prompts and coordination docs.
author: Claude Code---

# Multi-Agent Orchestration Setup

## Purpose

Analyze a phase's task breakdown, identify parallelizable work paths, and generate
all documents needed to coordinate multiple Claude agents working in parallel.

## When to Use

- User has a `docs/PHASEx_TASKS.md` file with epics and dependencies
- User wants to parallelize implementation across multiple agents
- User asks to "set up orchestration for Phase X"

## Process

### Phase 1: Dependency Analysis

Read the tasks file and extract the dependency graph:

1. Identify all epics and their dependencies
2. Build a dependency graph
3. Identify the critical path (longest chain)
4. Find maximum parallel paths
5. Verify each dependency makes sense

Ask the user to verify dependencies using AskUserQuestion.

### Phase 2: Determine Agent Count

Agent count is determined by **parallelism**, not by predefined roles.

```
agents = min(max_parallel_paths, 4)
```

Where `max_parallel_paths` = Maximum epics that can run simultaneously.

Present agent count recommendation and ask for confirmation.

### Phase 3: Assign Epics to Agents

**Agents MUST have human names.** See GUIDE.md for naming rules.

Assign epics based on the dependency graph:

- **[Lead]**: Gets critical path epics (the blocking work)
- **Other agents**: Get epics that can run in parallel once unblocked

Create an assignment matrix and ask user for approval:

```markdown
| Agent  | Epics | Blocked By                 |
| ------ | ----- | -------------------------- |
| [Lead] | X, Y  | -                          |
| [Name] | A, B  | [Lead]'s go-ahead          |
| [Name] | C, D  | [Lead]'s go-ahead + Epic Y |
```

### Phase 4: Generate Documents

Create two documents using the co-located templates.

#### 4.1 Implementation Prompt

File: `docs/prompts/PHASEX_IMPLEMENTATION_PROMPT.md`

Key sections:

- Context
- Required Reading
- Agents & Dependencies table
- Coordination Strategy
- Polling Strategy

#### 4.2 Coordination Document

File: `docs/PHASEX_COORDINATION.md`

Key sections:

- Status table (all epics start ⏳)
- Questions table ([Lead] populates, owner answers)
- Messages (timestamped agent-to-agent)
- Work Log (per agent)
- Decisions table

### Phase 5: Define Coordination Strategy

**CRITICAL**: All agents except [Lead] must wait for TWO things:

1. **[Lead]'s go-ahead**: [Lead] asks questions, gets answers, then posts "GO" in Messages
2. **Their blockers**: Any epic dependencies must show ✅

```
[Lead]:
- Starts immediately
- Uses AskUserQuestion to clarify ambiguities for ALL epics
- Logs answers in Questions table
- Posts "GO - all questions answered" in Messages when ready
- Begins work on their epics

[Other agents]:
- Poll coordination doc for [Lead]'s "GO" message
- THEN check if their specific blockers show ✅
- Only start work when BOTH conditions met
```

### Phase 6: Define Polling Strategies

Include these polling strategies in the prompt:

#### Strategy 1: Wait for GO + Blockers (for starting work)

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

#### Strategy 2: Wait for ANY update (for mid-work questions)

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

### Phase 7: Output Summary

Present the generated artifacts:

```markdown
## Orchestration Setup Complete

Created:

- `docs/prompts/PHASEX_IMPLEMENTATION_PROMPT.md`
- `docs/PHASEX_COORDINATION.md`

Agent assignments:

- [Lead]: Epics X, Y - starts immediately, asks questions first
- [Name]: Epics A, B - waits for [Lead]'s go-ahead
- [Name]: Epics C, D - waits for [Lead]'s go-ahead + Epic Y

To launch:

1. Open N Claude Code terminals
2. Give each agent their prompt + assigned epics
3. [Lead] starts first, others poll and wait for GO signal
```

## Anti-Patterns to Avoid

1. **Subagent busy work**: "While waiting, explore codebase" - wastes tokens
2. **Reading unstable files**: Files the blocking agent is creating may change
3. **Starting before GO**: Other agents must wait for [Lead]'s go-ahead

## Co-located Files

This skill includes these files in the same directory:

- `GUIDE.md` - Comprehensive orchestration guide
- `IMPLEMENTATION_PROMPT_TEMPLATE.md` - Template for agent prompts
- `COORDINATION_TEMPLATE.md` - Template for coordination docs

## Checklist Before Launch

- [ ] Dependencies verified with user
- [ ] Agent count based on parallelism
- [ ] Epic assignments approved
- [ ] Implementation prompt generated
- [ ] Coordination doc generated
- [ ] [Lead] knows to ask questions first and post GO when ready
