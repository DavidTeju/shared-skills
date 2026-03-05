# Phase [X] Implementation Prompt

> **Instructions**: Copy this template, replace `[X]` with phase number,
> fill in bracketed sections, delete this instruction block.

## Context

Implementing Phase [X] ([Phase Name]) for [Project]. [N] agents work in parallel,
coordinating via `docs/PHASE[X]_COORDINATION.md`.

## Required Reading

1. `docs/ARCHITECTURE.md` - Tech stack, patterns, data models
2. `docs/SPEC.md` - Product requirements, user context
3. `docs/PHASE[X]_TASKS.md` - Task breakdown with acceptance criteria
4. `docs/PHASE[X]_COORDINATION.md` - Shared state for coordination

---

## Agents & Dependencies

| Agent  | Epics | Blocked By                 |
| ------ | ----- | -------------------------- |
| [Lead] | X, Y  | -                          |
| [Name] | A, B  | [Lead]'s go-ahead          |
| [Name] | C, D  | [Lead]'s go-ahead + Epic Y |

---

## Coordination Strategy

**[Lead]**:

- Starts immediately
- Uses AskUserQuestion to clarify ambiguities for **ALL** epics for all engineers
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

## Polling Strategies

### Strategy 1: Wait for GO + Blockers (for starting work)

```bash
COORD_FILE="docs/PHASE[X]_COORDINATION.md"
LAST_MTIME=""

while true; do
  CURRENT_MTIME=$(stat -f %m "$COORD_FILE" 2>/dev/null || stat -c %Y "$COORD_FILE")

  if [ "$CURRENT_MTIME" != "$LAST_MTIME" ]; then
    if grep -q "GO.*all questions answered" "$COORD_FILE"; then
      if grep -q "Epic [BLOCKER].*✅" "$COORD_FILE"; then
        echo "UNBLOCKED"
        break
      fi
    fi
    LAST_MTIME="$CURRENT_MTIME"
  fi

  sleep 60
done
```

### Strategy 2: Wait for ANY update (for mid-work questions)

Use when you post a question and need to wait for a response:

```bash
COORD_FILE="docs/PHASE[X]_COORDINATION.md"
LAST_MTIME=$(stat -f %m "$COORD_FILE" 2>/dev/null || stat -c %Y "$COORD_FILE")

echo "Waiting for any update..."
while true; do
  sleep 60
  CURRENT_MTIME=$(stat -f %m "$COORD_FILE" 2>/dev/null || stat -c %Y "$COORD_FILE")

  if [ "$CURRENT_MTIME" != "$LAST_MTIME" ]; then
    echo "File updated"
    break
  fi
done
```

### While Waiting (Safe Preparation)

Read STABLE files only:

- `docs/ARCHITECTURE.md` - patterns to follow
- `docs/SPEC.md` - product requirements
- Existing similar features in `src/features/*/`

**DO NOT read** files the blocking agent is actively creating.

---

## Notes

- Follow existing patterns in `src/features/` and `src/lib/trpc/routers/`
- [Add phase-specific constraints here]
- [Add out-of-scope items here]

---

## Unblock Notification Template

When completing an epic that unblocks others, post to Messages:

```
[YYYY-MM-DD HH:MM] [YourName]: Epic [X] complete. Files: [list]. @[Name] unblocked.
```
