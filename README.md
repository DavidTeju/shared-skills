# shared-skills

All Claude Code / OpenClaw skills in one place. Symlinked into projects via `setup.sh`.

## Structure

```
skills/
  beeper/SKILL.md
  femi-calendar/SKILL.md
  ...
```

## Setup

```bash
# Local (Claude Code) — creates symlinks into user + project skill dirs
./setup.sh local

# Preview what would change
./setup.sh local --dry-run

# VPS (OpenClaw) — pulls repo + creates symlinks
./setup.sh openclaw
```

## Skill inventory

### User-level (all projects)

| Skill | Category |
|-------|----------|
| ai-agent-debugging-guide | Engineering patterns |
| async-dedup-race-in-streaming-pipelines | Engineering patterns |
| fix-at-appropriate-layer | Engineering patterns |
| git-commit-practices | Engineering patterns |
| test-debugging-without-hacking | Engineering patterns |
| agent-team-orchestration-patterns | Agent/orchestration |
| bug-basher-5000 | Agent/orchestration |
| claude-code-session-transcript-analysis | Agent/orchestration |
| claude-code-token-usage | Agent/orchestration |
| claudeception | Agent/orchestration |
| code-review | Agent/orchestration |
| ralph-wiggum-loop-setup | Agent/orchestration |
| browser-tab-resource-investigation | macOS/system |
| swift-macos-native-apis | macOS/system |
| speech-to-text | macOS/system |
| gog | Google tools |
| google-calendar-ics-timezone-handling | Google tools |
| notion-child-page-preservation | Notion |
| notion-page-link-syntax | Notion |
| git-worktree-nextjs-prisma | Next.js/Prisma |
| nextjs-client-server-boundary-dns-error | Next.js/Prisma |
| nextjs-prisma-client-component-import | Next.js/Prisma |
| prisma-7-driver-adapter | Next.js/Prisma |
| prisma-migration-drift-recovery | Next.js/Prisma |
| vitest-class-mocking | Vitest |
| vitest-mock-implementation-persistence | Vitest |
| vitest-recharts-mocking | Vitest |

### Project: personal_assistant_claude

| Skill | Purpose |
|-------|---------|
| beeper | Cross-platform messaging CLI |
| femi-calendar | Google Calendar management |
| macos-messages-contacts-access | macOS Messages/Contacts access |
| message-review | Scan messages for action items |
| notion-style-matching | Match Notion formatting preferences |
| notion-todo-organization | Organize Notion todo database |
| querying-and-updating-notion | Notion MCP vs API decision routing |
| swarm-research | Multi-agent research with varied context |

### Project: peronal_budget_tracking

| Skill | Purpose |
|-------|---------|
| architecture-parity-review | Architecture consistency checks |
| multi-agent-orchestration | Multi-agent coordination patterns |

## Adding a new skill

1. Create `skills/<name>/SKILL.md`
2. Add it to the appropriate list in `setup.sh`
3. Run `./setup.sh local` to symlink
4. `git push` then `./setup.sh openclaw` to deploy to VPS
