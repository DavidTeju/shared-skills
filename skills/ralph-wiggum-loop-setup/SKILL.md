---
name: ralph-wiggum-loop-setup
description: |
  Set up and run a Ralph Wiggum autonomous loop for Claude Code when the official plugin
  isn't available. Use when: (1) user asks about "Ralph Wiggum loop" or "Ralph loop",
  (2) need to apply many well-specified code changes autonomously, (3) want to run Claude
  Code in a bash loop with progress tracking and oscillation detection, (4) official
  ralph-wiggum plugin is not in the marketplace. Covers: manual bash loop setup, PROMPT.md
  design, PROGRESS.md tracker, completion signal gotchas, oscillation detection, permission
  configuration, and when NOT to use Ralph loops.
author: Claude Code---

# Ralph Wiggum Loop — Manual Setup for Claude Code

## Problem

The Ralph Wiggum loop is an autonomous iteration pattern where Claude Code repeatedly
processes a prompt, with state persisting in files between iterations. The official plugin
(`ralph-wiggum@claude-plugins-official`) may not be available in the marketplace. This
skill covers setting up a manual bash loop that replicates the same behavior.

## Context / Trigger Conditions

- User asks about "Ralph Wiggum loop" or wants autonomous iteration
- Many well-specified changes need applying (5+ changes with clear before/after code)
- Each change has verifiable success criteria (typecheck, tests, linting)
- The official plugin install fails: `Plugin "ralph-wiggum" not found in any configured marketplace`

## When Ralph Loops Work Well

- **Well-specified fixes** with exact before/after code (e.g., from a code review document)
- **Test-driven tasks** where pass/fail is automatic
- **Mechanical refactoring** across many files with clear patterns
- **Build fix loops** where compilation errors guide the next iteration

## When Ralph Loops DON'T Work

- Tasks requiring human judgment or design decisions
- Exploratory work with unclear success criteria
- Tasks where the user prefers interactive Q&A
- Changes to tightly coupled files where ordering creates merge-conflict-like issues

## Solution: Three-File Setup

### 1. PROGRESS.md — State Tracker

The agent reads this each iteration to know what's done and what's next.

```markdown
# Fix Progress

Statuses: `[ ]` = pending, `[x]` = done, `[BLOCKED]` = stuck (move on)

## Phase 1 — Independent fixes
- [ ] Fix A: description (src/path/to/file.ts)
- [ ] Fix B: description (src/path/to/file.ts)

## Phase 2 — Dependent fixes (Fix C depends on Fix A)
- [ ] Fix C: description (src/path/to/file.ts)

<!-- When ALL fixes above are done, add RALPH_DONE on its own line below -->
```

**CRITICAL GOTCHA**: The completion signal (`RALPH_DONE`) must NOT appear anywhere else in
the file — not even in comments. Use `grep -q "^RALPH_DONE$"` (anchored regex) in the
bash script to avoid false matches against HTML comments or instructions that mention the
signal string. This bit us in practice: `<!-- ALL_FIXES_COMPLETE -->` triggered early termination.

### 2. PROMPT.md — Agent Instructions

Key design principles:
- **One task per iteration**: The agent does ONE fix, commits, updates PROGRESS.md, and stops.
  This gives each fix fresh context and clean git history.
- **Read PROGRESS.md first**: Agent finds the next `[ ]` item. Within a phase, pick by
  dependency order first, then by risk/importance (architectural > integration > unknown unknowns > easy wins).
  Without explicit guidance, agents default to easiest items first.
- **Read the spec document**: Agent reads the detailed fix instructions
- **Verify after each fix**: `npx tsc --noEmit` or test command
- **Commit per fix**: Isolated git commits for easy rollback
- **Anti-oscillation**: If stuck after 2 attempts, mark `[BLOCKED]` and move on

Include these sections:
1. **Workflow** (numbered steps)
2. **What NOT To Do** (explicit restrictions)
3. **Context** (codebase-specific info the agent needs)
4. **Dependency Notes** (ordering constraints between fixes)

### 3. ralph-loop.sh — The Bash Loop

```bash
#!/bin/bash
MAX_ITERATIONS=50
ITERATION=0
STALL_COUNT=0
LAST_PROGRESS_HASH=""
LOG_FILE="scripts/ralph-loop.log"
COOLDOWN_SECONDS=5

cd "$(dirname "$0")/.." || exit 1

# CRITICAL: Unset to allow nested Claude invocation from within a Claude Code session
unset CLAUDECODE

echo "=== Ralph Loop Starting at $(date) ===" | tee -a "$LOG_FILE"

while [ $ITERATION -lt $MAX_ITERATIONS ]; do
  ITERATION=$((ITERATION + 1))
  echo "--- Iteration $ITERATION / $MAX_ITERATIONS --- $(date)" | tee -a "$LOG_FILE"

  # Crash recovery: reset dirty state from a crashed previous iteration
  git diff --quiet || git checkout .
  git diff --cached --quiet || git reset HEAD .

  # Completion check (anchored regex!)
  if grep -q "^RALPH_DONE$" PROGRESS.md 2>/dev/null; then
    echo "RALPH_DONE detected. Stopping." | tee -a "$LOG_FILE"
    break
  fi

  # Oscillation detection
  CURRENT_HASH=$(md5 -q PROGRESS.md 2>/dev/null || md5sum PROGRESS.md | cut -d' ' -f1)
  if [ "$CURRENT_HASH" = "$LAST_PROGRESS_HASH" ]; then
    STALL_COUNT=$((STALL_COUNT + 1))
    if [ $STALL_COUNT -ge 3 ]; then
      echo "ABORT: 3 stalls. Agent stuck." | tee -a "$LOG_FILE"
      break
    fi
  else
    STALL_COUNT=0
    LAST_PROGRESS_HASH="$CURRENT_HASH"
  fi

  # Progress counter
  DONE=$(grep -c '^\- \[x\]' PROGRESS.md 2>/dev/null || echo 0)
  TODO=$(grep -c '^\- \[ \]' PROGRESS.md 2>/dev/null || echo 0)
  echo "Progress: $DONE done, $TODO remaining" | tee -a "$LOG_FILE"

  # Run Claude
  claude -p "$(cat PROMPT.md)" \
    --dangerously-skip-permissions \
    --verbose \
    --disallowedTools "WebSearch WebFetch Task" \
    2>&1 | tee -a "$LOG_FILE"

  sleep $COOLDOWN_SECONDS
done

echo "=== Loop finished at $(date) ===" | tee -a "$LOG_FILE"
```

## Key Design Decisions

### One fix per iteration vs batch
One fix per iteration is strongly recommended because:
- Fresh context window each time (no accumulation)
- Clean git commit per fix (easy `git revert`)
- Oscillation is detectable (PROGRESS.md hash changes)
- If the agent breaks something, only one fix is affected

### Permission model
- `--dangerously-skip-permissions`: Required for AFK mode (no human to click "allow")
- `--disallowedTools "WebSearch WebFetch Task"`: Prevent the agent from going online or spawning sub-agents
- Alternative: Use `--allowedTools "Read Write Edit Glob Grep Bash"` for tighter control

### Oscillation detection
Hash PROGRESS.md each iteration. If unchanged for 3 consecutive iterations, the agent is
stuck and the loop aborts. This prevents burning iterations on an impossible fix.

### Stashing before running
If the working tree has uncommitted changes, stash them first:
```bash
git stash push -m "pre-ralph-loop stash"
```
This gives the agent a clean baseline and prevents its commits from mixing with your WIP.

## Pre-Flight Checklist

Before running the loop:
- [ ] All target source files exist and are in committed state
- [ ] PROGRESS.md has no accidental completion signal matches
- [ ] PROMPT.md references the correct spec document path
- [ ] Dependency ordering in PROGRESS.md is correct
- [ ] `ralph-loop.sh` is executable (`chmod +x`)
- [ ] Working tree is clean (stash or commit WIP)
- [ ] Spec document (fix instructions) is accessible to the agent
- [ ] **PRD audit**: Cross-reference spec document against PROGRESS.md tasks for missing work (see "PRD Audit" section below)
- [ ] **PROGRESS.md is untracked** (see "PROGRESS.md Tracking Hazard" below)
- [ ] **Pre-mortem**: dispatch agents to review task descriptions for ambiguity and missing guardrails before starting. Common patterns that autonomous agents miss: tasks that only describe the happy path (no error/failure handling), tasks that reference APIs without specifying semantic contracts (e.g., "acquire lock" without "inside a $transaction"), parallel pipelines with inconsistent safeguards (e.g., items pipeline missing thresholds that transaction pipeline has), shared return types with undefined semantics for new operating modes

## Monitoring

From another terminal:
```bash
tail -f scripts/ralph-loop.log      # live log
cat PROGRESS.md                      # check progress
git log --oneline -20                # see commits
```

## Verification

After the loop completes:
1. Check PROGRESS.md — all items should be `[x]` or `[BLOCKED]`
2. Run full test suite: `npx vitest run`
3. Run typecheck: `npx tsc --noEmit`
4. Review git log for clean commit history
5. Spot-check a few fixes against the spec document

## Real-World Results

**Run 1** — 18 receipt matching fixes:
- **18/18 fixes completed** in 19 iterations (1 extra for completion detection)
- **0 blocked**, 0 oscillations
- **~42 minutes** total runtime
- **16 files changed**, +577/-370 lines
- Every fix landed on the first try

**Run 2** — 60-task auto-categorization feature (full feature build, not just fixes):
- **60/60 tasks completed** across 88 iterations (75 first run + 13 after stall recovery)
- **0 blocked**, 1 stall (agent committed code but didn't update PROGRESS.md — see gotchas)
- **~3 hours 9 minutes** total runtime (~3 min/task average)
- **82 files changed**, +21,756/-1,289 lines, 93 commits
- **135 tests** across 9 test files, all passing
- Covered: schema changes, Prisma migration, 11 services, 18 integration hooks, tRPC router, seed data, unit + integration tests

## Operational Gotchas (v1.1)

### CLAUDECODE Environment Variable
When launching the loop from inside a Claude Code session (e.g., user asks you to start it),
`claude -p` will refuse with: `"Error: Claude Code cannot be launched inside another Claude Code session."`
Fix: Add `unset CLAUDECODE` to the script after `cd`, before the loop. This is already in the
bash template above. Without this, every iteration fails immediately and stall detection triggers.

### PROGRESS.md Must Stay Untracked
**Never commit PROGRESS.md.** The crash recovery line `git checkout .` resets all tracked files.
If PROGRESS.md is tracked, crash recovery reverts it — losing progress markers and causing
stall loops where the agent retries already-completed tasks.

The PROMPT.md must explicitly instruct the agent: "Do NOT `git add` PROGRESS.md. Only stage
and commit source code files." If PROGRESS.md accidentally gets committed mid-run and you need
to fix a stall, you must `git rm --cached PROGRESS.md && git commit` to untrack it before
restarting.

### PRD Audit (Multi-Agent)
Before starting the loop, systematically compare the spec document against PROGRESS.md tasks
using **multiple independent Opus subagents** in parallel. Each agent reviews a different
dimension of completeness. This catches gaps a single-pass review misses.

In practice, this audit routinely finds 5-10 missing tasks that would have caused
stalls, blocked dependencies, or incomplete functionality if discovered mid-loop.

**How to run the audit** — dispatch 4 independent Opus agents in parallel, each with a
different audit focus. Use `Task` tool with `subagent_type: "general-purpose"` and
`model: "opus"` for each. All agents read the same spec + PROGRESS.md but look for
different classes of gaps:

**Agent 1 — Schema & Data Model Completeness**
```
Read the spec's schema section and PROGRESS.md. For every field, enum, model, index,
and relation in the spec, verify a PROGRESS.md task creates or modifies it. Check:
- Missing fields on existing models
- Missing indexes (especially composite/unique)
- Missing inverse relations (Prisma requires both sides)
- Enum values that don't match the spec
- Seed data changes (new entries, removals, defaults)
Report each gap as: "[MISSING] description — spec section X says Y but no task covers it"
```

**Agent 2 — Integration Points & Hook Exhaustiveness**
```
Read the spec's integration points section and PROGRESS.md. For EVERY code path that
creates, updates, links, unlinks, or mutates the affected entities, verify a task exists.
Audit technique: grep the codebase for the relevant Prisma operations and mutation calls.
Check:
- Every creation path has a post-create hook
- Every link/unlink path has the sync helper + post-commit handler
- Every user mutation path sets the correct source/confidence
- Cron jobs, background tasks, and one-time scripts are wired
Report each gap as: "[MISSING HOOK] file:line — this code path has no task in PROGRESS.md"
```

**Agent 3 — Consumer Migration & Cross-Cutting Concerns**
```
Read the spec for any "consumers that need migration" lists, shared utilities, and
cross-cutting concerns. For each listed consumer, verify a PROGRESS.md task migrates it.
Also check:
- Are there consumers the spec DIDN'T list? (grep the codebase for the old pattern)
- Are there prompt templates, AI configurations, or cost tracking changes needed?
- Are there deployment/migration steps (db wipe, seed, backfill) that need tasks?
- Are there cron maintenance jobs (cleanup, decay, expiration)?
Report: "[MISSING CONSUMER] file:function — uses old pattern but no migration task"
```

**Agent 4 — Test Coverage & Verification Gaps**
```
Read the spec's testing section and PROGRESS.md test tasks. For every test file the spec
lists, verify a task creates it. Also check:
- Are integration tests specified but missing from PROGRESS.md?
- Do unit test descriptions cover the key behaviors from the spec?
- Are there untestable tasks (tasks with no Verify command)?
- Are verification commands appropriate (tsc for type changes, vitest for logic)?
Report: "[MISSING TEST] spec says X but no test task covers it"
```

**After all 4 agents return**: Merge their findings, deduplicate, and add missing tasks
to PROGRESS.md before starting the loop. Prioritize [MISSING HOOK] findings as these
cause runtime bugs if skipped.

## Interleaved Reviewer (optional, for 30+ task loops)

For long loops, interleave review iterations into the implementation loop. Every Nth
iteration, the loop script swaps the implementer prompt for a review prompt. One agent,
one loop, alternating concerns. No concurrency, no staging files, no merge logic.

The review iteration reads recent commits, compares against the spec, and writes changes
directly to PROGRESS.md — either inserting new fix tasks or editing future task descriptions
to prevent pattern repetition. The implementer picks up these changes naturally on its
next iteration.

The reviewer must deeply understand the spec and the codebase — not just scan diffs, but
reason about downstream consequences, cross-service consistency, and whether the implementation
matches the plan's intent.

To implement: add a modulo check in the loop script to alternate prompts. Exempt review
iterations from stall detection (they don't change PROGRESS.md's task checkboxes). Typical
overhead: ~20% longer total runtime for review every 5 tasks.

## Notes

- The `claude -p` flag runs in non-interactive/print mode — tools still work
- Each iteration starts with a completely fresh context window
- State persists ONLY in files (PROGRESS.md, git history, source code)
- Max iterations is a cost safety net, not a performance target
- For macOS: `md5 -q` for hashing; for Linux: `md5sum | cut -d' ' -f1`
- The COOLDOWN_SECONDS prevents API rate limiting between iterations

## References

- [Geoffrey Huntley — Ralph Wiggum as a "software engineer"](https://ghuntley.com/ralph/)
- [Anthropic — Ralph Wiggum Plugin README](https://github.com/anthropics/claude-code/blob/main/plugins/ralph-wiggum/README.md)
- [AI Hero — 11 Tips For AI Coding With Ralph Wiggum](https://www.aihero.dev/tips-for-ai-coding-with-ralph-wiggum)
- [beuke.org — Ralph Wiggum Loop failure modes](https://beuke.org/ralph-wiggum-loop/)
- [Secure Trajectories — Supervising Ralph](https://securetrajectories.substack.com/p/ralph-wiggum-principal-skinner-agent-reliability)
