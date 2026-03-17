# shared-skills

All Claude Code / OpenClaw skills in one place. Symlinked into projects via `setup.sh`.

## Structure

```
skills/           # Skill definitions (SKILL.md per skill)
hooks/user-level/ # Claude Code hooks (symlinked to ~/.claude/hooks/)
scripts/          # Helper scripts used by setup.sh
setup.sh          # Symlinks skills + hooks, registers hooks in settings.json
```

## Setup

```bash
# Local (Claude Code) — symlinks skills + hooks, registers hooks in settings.json
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
| create-cli-skill | Agent/orchestration |
| claude-code-session-transcript-analysis | Agent/orchestration |
| claude-code-token-usage | Agent/orchestration |
| claudeception | Agent/orchestration |
| code-review | Agent/orchestration |
| ralph-wiggum-loop-setup | Agent/orchestration |
| browser-tab-resource-investigation | macOS/system |
| playwright-cli | macOS/system |
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

## Readonly Gate Hook

The **safely-skip-permissions** hook (`readonly-gate.sh`) auto-approves read-only Claude Code tool calls (file reads, searches, git status, etc.) so you aren't prompted for every safe operation. Writes still require confirmation.

**Install (standalone — no need to clone the full repo):**

```bash
# macOS / Linux
git clone https://github.com/DavidTeju/shared-skills.git /tmp/shared-skills
bash /tmp/shared-skills/hooks/user-level/install-readonly-gate.sh
rm -rf /tmp/shared-skills
```

```powershell
# Windows (PowerShell) — requires Perl (e.g. Strawberry Perl) on PATH
git clone https://github.com/DavidTeju/shared-skills.git $env:TEMP\shared-skills
& $env:TEMP\shared-skills\hooks\user-level\install-readonly-gate.ps1
Remove-Item -Recurse -Force $env:TEMP\shared-skills
```

This copies the hook to `~/.claude/hooks/` and registers it in `~/.claude/settings.json`. Run the install script again anytime to update to the latest version.

To preview what it would do: `bash install-readonly-gate.sh --dry-run` (or `.\install-readonly-gate.ps1 -DryRun` on Windows)

Unlike `settings.json`'s config which uses a simple allowlist, this is more intelligent. It's a two-phase bash classifier. Named tools (Read, Grep, Glob, etc.) are checked against an allowlist, but Bash commands go through a pipeline-aware parser that splits on `|`, `&&`, `;`, and `||`, then classifies each segment individually. It handles quoted strings, `$()` command substitutions, environment variable prefixes, dangerous flags on otherwise-safe commands (e.g. `find -exec`, `sed -i`, `awk system()`), output redirects vs. safe `/dev/null` redirects, and multi-word read patterns like `git log`, `gh pr list`, and `gog calendar events`. When in doubt, it defers to the normal permission prompt. The principle is: false negatives are safe, false positives are not.

## Adding a new skill

1. Create `skills/<name>/SKILL.md`
2. Add it to the appropriate list in `setup.sh`
3. Run `./setup.sh local` to symlink
4. `git push` then `./setup.sh openclaw` to deploy to VPS
