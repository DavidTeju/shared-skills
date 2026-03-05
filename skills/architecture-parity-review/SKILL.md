---
name: architecture-parity-review
description: |
  Review session transcripts to ensure ARCHITECTURE.md stays in sync with implementation decisions.
  Use when: (1) after completing a major feature/epic, (2) periodic architecture audits,
  (3) onboarding new contributors who need accurate docs, (4) before releases to ensure docs
  reflect reality. Spawns parallel agents that cross-reference transcript decisions against
  docs/ARCHITECTURE.md. Project-specific to Flow budget tracking app.
author: Claude Code
---

# Architecture Parity Review

## Problem
Long-running implementation sessions make many technical decisions that should be documented
in ARCHITECTURE.md. Without systematic review, docs drift from reality.

## Prerequisites

This skill builds on the general transcript analysis skill:
- **See:** `claude-code-session-transcript-analysis` (user-scope skill)

## Context / Trigger Conditions
- Just completed a major epic or feature
- User asks "is ARCHITECTURE.md up to date?"
- Periodic audit (e.g., before release)
- New team member needs accurate documentation
- Previous session hit context limit mid-work

## Solution

### Step 1: Identify Session to Analyze

Find the session file:
```bash
ls -la ~/.claude/projects/<project-path>/
```

Sessions are named by UUID (e.g., `7912b5b1-b1dd-403e-b4ff-a97cdb9df442.jsonl`).
Most recent by timestamp is usually the target.

### Step 2: Check File Size

```bash
wc -l ~/.claude/projects/<project-path>/{session}.jsonl
```

- **<500 lines:** Single agent can handle
- **500-2000 lines:** Split into 4 parallel agents
- **>2000 lines:** Split into more agents (one per ~500 lines)

### Step 3: Spawn Parallel Agents with ARCHITECTURE.md Context

**Critical:** Each agent MUST load ARCHITECTURE.md first, then analyze their transcript portion.

Example prompt for each agent:
```
You are analyzing a Claude Code session transcript to extract decisions and check ARCHITECTURE.md parity.

**STEP 1: Load ARCHITECTURE.md as your baseline**
```bash
cat docs/ARCHITECTURE.md
```
Read this FIRST. Understand what's documented.

**STEP 2: Analyze your transcript portion**
```bash
sed -n '{START},{END}p' ~/.claude/projects/<project-path>/{session}.jsonl
```

**YOUR PORTION:** Lines {START}-{END}

**FOR EACH DECISION FOUND:**
1. What was decided
2. Why (from thinking blocks)
3. **PARITY CHECK:** Is this in ARCHITECTURE.md?
   - [ ] Documented correctly
   - [ ] Missing - needs addition
   - [ ] Conflicts - [explain]
4. **Suggested Addition:** [exact text to add if needed]

DO NOT EDIT ANY FILES. Report findings only.
```

### Step 4: Synthesize Findings

After all agents complete, consolidate into a single report:
- `docs/ARCHITECTURE_PARITY_REPORT.md`

Structure:
```markdown
# ARCHITECTURE.md Parity Report

## Executive Summary
- Total gaps found
- Conflicts found
- Session coverage

## Gaps (Prioritized)

### High Priority
[Core architecture missing]

### Medium Priority
[Implementation details missing]

### Low Priority
[Process/housekeeping items]

## Conflicts Found
[Any contradictions between code and docs]

## Suggested Updates
[Exact text to add/change]
```

### Step 5: Apply Updates

After user reviews the report, update ARCHITECTURE.md:
1. Apply suggested additions
2. Resolve any conflicts
3. Update "Last Updated" date
4. Add entry to changelog at bottom of file

## Project-Specific Sections to Check

For Flow, ensure these ARCHITECTURE.md sections are current:

| Section | Check For |
|---------|-----------|
| Tech Stack | Version numbers, new dependencies |
| Project Structure | New directories, moved files |
| Database & ORM | New models, schema changes |
| Receipt Matching | Matcher implementations, signals, scoring |
| External Integrations | Gmail, SimpleFIN, any new APIs |
| Testing Strategy | New test patterns, benchmark system |
| Development Workflow | Process changes, commit guidelines |

## Verification

After updates:
1. Read through ARCHITECTURE.md for consistency
2. Spot-check 2-3 documented paths actually exist in codebase
3. Ensure changelog entry added

## Example Output

See: `docs/ARCHITECTURE_PARITY_REPORT.md` for a real example from the Phase 2 implementation review.

## Notes

- Run this after any epic completion
- Don't forget the "Last Updated" date in header
- ARCHITECTURE.md changelog is append-only (per CLAUDE.md)
- Some findings may belong in BUGS.md instead (known limitations)
