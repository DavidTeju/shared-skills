---
name: claude-code-session-transcript-analysis
description: |
  Analyze Claude Code session transcripts to extract decisions, learnings, and state.
  Use when: (1) recovering interrupted sessions, (2) extracting what an agent did,
  (3) auditing decisions made during long-running tasks, (4) reconstructing agent state
  after context limit. Covers JSONL format, parsing commands, and parallel analysis patterns.
author: Claude Code
---

# Claude Code Session Transcript Analysis

## Problem
Claude Code sessions can hit context limits or get interrupted. Reconstructing what happened,
what decisions were made, and where to continue requires parsing the session transcript.

## Context / Trigger Conditions
- Session hit context limit ("Conversation too long")
- Need to recover an interrupted agent's state
- Want to audit decisions made during a long session
- User asks "what did the previous agent do?"
- Need to extract learnings from a completed session

## File Location

Session transcripts are stored at:
```
~/.claude/projects/{project-path-with-dashes}/{session-id}.jsonl
```

Example:
```
~/.claude/projects/-Users-jane-projects-my-app/7912b5b1-b1dd-403e-b4ff-a97cdb9df442.jsonl
```

## JSONL Format

Each line is a JSON object representing a message/event:

```javascript
{
  "type": "assistant" | "user" | "progress",
  "message": {
    "role": "assistant" | "user",
    "content": [
      { "type": "thinking", "thinking": "Claude's reasoning..." },
      { "type": "tool_use", "name": "Bash", "input": {...} },
      { "type": "tool_result", "content": "..." },
      { "type": "text", "text": "Response to user..." }
    ]
  },
  "timestamp": "2026-02-01T05:12:44.876Z",
  "uuid": "...",
  "parentUuid": "..."  // Links messages in sequence
}
```

## Useful Extraction Commands

### Check file size
```bash
wc -c ~/.claude/projects/{path}/{session}.jsonl   # bytes
wc -l ~/.claude/projects/{path}/{session}.jsonl   # lines (messages)
```

### Read from end (most recent activity)
```bash
tail -c 800000 session.jsonl    # Last ~800KB
tail -50 session.jsonl          # Last 50 messages
```

### Read specific line ranges
```bash
head -500 session.jsonl         # First 500 lines
sed -n '500,1000p' session.jsonl  # Lines 500-1000
sed -n '1000,1500p' session.jsonl # Lines 1000-1500
```

### Extract user prompts (excluding tool results)
```bash
grep '"type":"user"' session.jsonl | grep -v 'tool_result' | \
  python3 -c "import sys, json; [print(json.loads(line)['message']['content'][:2000]) for line in sys.stdin]"
```

### Extract task subjects (if TaskCreate was used)
```bash
grep -o '"subject":"[^"]*"' session.jsonl | sort -u
```

### Find specific tool calls
```bash
grep -E '"name":"Task(Create|Update|List)"' session.jsonl
grep '"name":"Write"' session.jsonl
grep '"name":"Edit"' session.jsonl
```

### Extract thinking blocks (Claude's reasoning)
```bash
grep '"type":"thinking"' session.jsonl | \
  python3 -c "import sys, json; [print(json.loads(line)['message']['content'][0]['thinking'][:500]) for line in sys.stdin]"
```

### Get last N messages with formatted output
```bash
tail -50 session.jsonl | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        data = json.loads(line)
        if data.get('type') == 'assistant':
            content = data.get('message', {}).get('content', [])
            for c in content:
                if c.get('type') == 'thinking':
                    print('THINKING:', c.get('thinking', '')[:500])
                elif c.get('type') == 'tool_use':
                    print('TOOL:', c.get('name'), '-', json.dumps(c.get('input', {}))[:300])
                elif c.get('type') == 'text':
                    print('TEXT:', c.get('text', '')[:500])
    except: pass
"
```

## Parallel Analysis Pattern

For large transcripts (>1MB), spawn parallel subagents to analyze different portions:

```
Agent 1: Lines 1-500 (session start, initial directives)
Agent 2: Lines 500-1000 (early implementation)
Agent 3: Lines 1000-1500 (mid-session work)
Agent 4: Lines 1500-end (final state, where it stopped)
```

### Critical Best Practice

**Always load baseline context first.** If checking against documentation (e.g., ARCHITECTURE.md),
each agent should:

1. Read the reference document FIRST
2. THEN analyze their transcript portion
3. Flag discrepancies in real-time

❌ **Wrong:** Analyze transcript → separate agent checks docs
✅ **Right:** Each agent loads docs first → analyzes with context

This catches "decision X was made but docs say Y" immediately.

## What to Extract

1. **User's original directive** - Search early messages without `tool_result`
2. **Task list state** - Look for TaskCreate/TaskUpdate to reconstruct todos
3. **Thinking blocks** - Reveal intent and decision-making rationale
4. **Final activity** - `tail` the file to see what was happening when stopped
5. **Subagent spawns** - Look for `Task` tool calls with `subagent_type`
6. **Files created/modified** - Look for Write/Edit tool calls
7. **Commits made** - Look for `git commit` in Bash tool calls

## Recovery Document Template

When recovering an interrupted session, create a **comprehensive, actionable** document.
The goal is that a new agent can read it and immediately continue work.

### Required Sections

```markdown
# Agent Recovery Document

**Session ID:** `{session-id}`
**Agent Slug:** `{slug}` (if available)
**Stopped At:** {timestamp}
**Reason:** {context limit / error / user interrupt}

---

## Executive Summary

[2-3 sentences: What was being built, what the user's master directive was, where it stopped]

[Checklist of major milestones with status: ✅ DONE / ❌ NOT STARTED / 🔄 IN PROGRESS]

---

## Current State Summary

### Epics/Features Completed
| Epic | Name | Status |
|------|------|--------|
| 1 | Feature name | ✅ Complete |
| 2 | Feature name | 🔄 In progress |

### Task Status When Stopped
| ID | Subject | Status |
|----|---------|--------|
| 1 | Task name | ✅ Completed |
| 2 | Task name | 🔄 In Progress (stopped here) |
| 3 | Task name | ⏳ Blocked by 2 |

---

## What Exists in Codebase

[Full file trees for each completed/in-progress feature - use actual `ls` output]

```
src/features/example/
├── __tests__/
│   └── example.test.ts
├── services/
│   └── example.ts
└── index.ts
```

**Test status:** [X tests pass / fail]

---

## User's Master Directive

> [EXACT QUOTE from user - this is critical for understanding intent]

---

## Immediate Next Steps

### Step 1: [First action]
[Actual commands to run, not just description]
```bash
git add ...
git commit -m "..."
```

### Step 2: [Second action]
[If spawning subagents, include FULL PROMPTS ready to copy-paste]

### Step 3: [Continue pattern...]

---

## Key Technical Context

[Interfaces, types, patterns the next agent needs to know]

```typescript
// Key interface from the codebase
export interface Example {
  // ...
}
```

### Test Scenarios / Acceptance Criteria
| # | Scenario | Expected |
|---|----------|----------|
| 1 | Case 1 | Result 1 |

---

## Files to Reference
- **Task Breakdown:** `docs/TASKS.md`
- **Architecture:** `docs/ARCHITECTURE.md`
- [Other relevant files]

---

## Recreate Task List

[Recommended TaskCreate sequence with dependencies]

```
1. First task
2. Second task (blocked by 1)
3. Third task (blocked by 1)
...
```

---

## Summary

[3-4 bullet points: What to do immediately, in what order]

Good luck!
```

### Finding Loose Ends

Agents working on long tasks often lose track of things. When analyzing a transcript, actively look for:

1. **Mentioned but never done** - Agent said "I'll do X after Y" but never returned to X
2. **Started but abandoned** - Began a task, got distracted by an error, never finished
3. **User requests ignored** - User asked for something that got lost in the flow
4. **Failed silently** - A command failed but agent moved on without fixing
5. **Partial implementations** - Created a file but didn't finish all functions
6. **Missing tests** - Wrote code but skipped the tests they mentioned
7. **Uncommitted work** - Completed features sitting in working directory
8. **TODO comments** - Agent added TODOs intending to return to them

**How to find these:**
```bash
# Find TODO/FIXME comments in recently modified files
git diff --name-only | xargs grep -n "TODO\|FIXME\|XXX" 2>/dev/null

# Check for empty/stub files
find src -name "*.ts" -empty

# Look for "will do later" in thinking blocks
grep -o '"thinking":"[^"]*later[^"]*"' session.jsonl | head -10
```

Include a **Loose Ends** section in recovery docs when you find any:
```markdown
## Loose Ends Found

- [ ] Agent mentioned adding tests for X but never did (line ~450)
- [ ] User asked about Y at timestamp Z - no response found
- [ ] File `src/foo.ts` created but `bar()` function is a stub
```

### Quality Checklist

Before finalizing a recovery doc, verify:
- [ ] User's exact directive is quoted (not paraphrased)
- [ ] File trees are from actual `ls` commands (not guessed)
- [ ] Commands are copy-pasteable (not pseudocode)
- [ ] Subagent prompts are complete (if applicable)
- [ ] Test status is verified (actually ran tests)
- [ ] Task dependencies are explicit
- [ ] **Loose ends identified** (things started but not finished)
- [ ] Tone is encouraging ("Good luck!" not just dry facts)

## Verification

After analysis, verify by:
1. Checking that identified files actually exist in codebase
2. Running tests if agent claimed they pass
3. Confirming git log matches extracted commits

## Notes

- Large files (>10MB) may need chunked reading to avoid memory issues
- Timestamps are UTC
- `parentUuid` links create a tree structure for conversation flow
- Tool results appear as user messages with `tool_result` type
- Progress events (`type: "progress"`) can be skipped for most analyses
