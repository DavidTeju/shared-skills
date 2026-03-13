---
name: create-cli-skill
description: |
  Create agent-optimized CLI skill documentation. Use when: (1) "create a skill for <CLI>",
  (2) "document <CLI> for agents", (3) adopting a new CLI tool that needs an agent-friendly
  reference, (4) rewriting an existing CLI skill with better agent optimization. Runs a
  discover-analyze-generate-verify pipeline. Output: SKILL.md in ~/projects/shared-skills/skills/.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - WebSearch
  - WebFetch
  - AskUserQuestion
---

# create-cli-skill

Create CLI skill files that agents can use without trial-and-error. The #1 cause of wasted
agent turns with CLIs: unknown output shapes, missing error paths, and too many flags with
no ranking. This skill prevents all three.

**Complements claudeception** — this is proactive (document before use); claudeception is
reactive (extract after use). To update an existing CLI skill with new gotchas, edit it
directly rather than running either skill.

## Pipeline

### Phase 1: Discovery

Gather raw material. Budget your exploration — don't enumerate every flag.

1. Is the CLI installed? Run `<cli> --help`
2. Run `<cli> <subcommand> --help` for the subcommands that look relevant
3. `WebSearch` for `"<cli> documentation"` — find official docs, `llms.txt` if it exists
4. Check for existing skill: `ls ~/projects/shared-skills/skills/<cli-name>/`
5. Check MEMORY.md and CLAUDE.md for prior references

If an existing skill exists, ask: **rewrite or patch?**

### Phase 2: Analysis

Decide what goes in. Apply the 80/20 rule ruthlessly.

1. **Ask the user:** What are your top 3-5 use cases for this CLI?
2. For each use case, trace the command chain — what commands, what flags, what outputs feed into what inputs
3. Run representative commands to capture actual output (especially JSON shapes)
4. Classify every command:
   - **Always safe:** Read-only, no side effects, idempotent
   - **Ask first:** Creates/modifies data but idempotent (safe to retry)
   - **Never do without confirmation:** Non-idempotent writes, deletes, sends
5. Note gotchas: surprising defaults, flag conflicts, misleading errors, shell quoting issues

**Choose an organization style:**

| Style | When to use | Example |
|-------|-------------|---------|
| Workflow-oriented | CLI has distinct user journeys | beeper |
| Cheat-sheet | Flat set of independent commands | gog |
| Reference manual | Large CLI (30+ commands), needs layered depth | playwright-cli |

### Phase 3: Generation

Write the SKILL.md. Include only the sections the CLI needs.

```markdown
---
name: <cli-name>
description: |
  <What it does. "Use when:" with specific trigger phrases. Be precise enough
  for semantic matching to surface this skill when relevant.>
---

# <CLI Name>

<One-line purpose. Note wrapper script if one exists.>

## Quick Start
<Minimum setup: install, auth, env vars. Skip if obvious.>

## Core Workflows

### <Workflow 1 name>
<Full examples with copy-pasteable commands using real-looking values.>
<Use --format json (or equivalent) by default in every example.>
<Inline warning if there's a gotcha specific to this command.>

# Returns: {"id": "abc123", "name": "Example", "status": "active"}
# Key fields: id (use as --item-id in other commands), status

### <Workflow 2 name>
...

## Command Reference
<ONLY if >10 commands. One-liner per command for the long tail. Not exhaustive.>

## Safety

| Tier | Commands | Idempotent? | Notes |
|------|----------|-------------|-------|
| Always safe | list, get, search | Yes | Read-only |
| Ask first | update, create | Yes/No | Note which are safe to retry |
| Never auto | delete, send | No | Creates duplicates or destroys data on retry |

## Error Recovery

| Error | Type | Action |
|-------|------|--------|
| "Connection refused" | Permanent | <service> not running — start it |
| "401 Unauthorized" | Permanent | Token expired — re-auth (STOP, don't retry) |
| "Rate limited" | Transient | Wait and retry |
| "Not found" | Depends | Broaden search query / check ID format |

## Do NOT Use This For
<Negative constraints. What this CLI cannot do, common misuse patterns.>

## Gotchas
<Cross-cutting warnings not tied to a specific command.>
```

**Section decision matrix:**

| Section | Include when... |
|---------|----------------|
| Quick Start | Always (even if just env var) |
| Core Workflows | Always |
| Command Reference | CLI has >10 commands |
| Safety | CLI has write/delete operations |
| Error Recovery | CLI has known error modes or network dependencies |
| Do NOT Use This For | Always |
| Gotchas | Always |

**Rules that make the difference:**

- **Output shapes inline.** Show `# Returns: {...}` right after the command, annotate key fields. This eliminates the #1 cause of wasted agent turns.
- **JSON by default.** Every example should use the machine-readable output flag. If the agent copies the first example it sees, it should already be pipeable.
- **Warnings at point-of-use.** Don't just collect gotchas at the end — put `# WARNING:` inline where the agent will encounter the issue.
- **Real-looking values.** `--chat-id "!abc123:beeper.com"` not `--chat-id <chatId>`. Show what IDs actually look like so the agent can validate.
- **Rank the flags.** When a flag has 7 options, say which one to use by default. "Use `json` unless results > 50 items, then use `jsonl`."
- **Show pipelines.** `ID=$(cli search --format json | jq -r '.[0].id') && cli get "$ID"` — this is the agent's actual workflow.

### Phase 4: Verification

1. Re-run at least one command from each documented workflow — confirm examples work
2. Check YAML frontmatter is valid
3. Ask user: route to user-level or project-level?
4. Add skill name to the appropriate array in `~/projects/shared-skills/setup.sh`
5. Run `./setup.sh local --dry-run` to preview
6. Run `./setup.sh local` to activate

## Target size

~100-200 lines for the generated skill. If it's longer, you're over-documenting. If it's shorter than 60 lines, you're probably missing output shapes or error recovery.
