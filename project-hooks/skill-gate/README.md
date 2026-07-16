# skill-gate

Agent hooks that make sure the **right skill is loaded before a gated workflow runs**. When an
agent is about to do something a repo has opinions about — commit code, drive a browser, review a
PR — skill-gate nudges (or blocks) until the matching `SKILL.md` has actually been loaded.

Works with both **Claude Code** and the **GitHub Copilot CLI** from a single shared engine and one
manifest.

> This is a **project-level** hook system (it lives in a repo's `.claude/` + `.github/`), unlike the
> user-level hooks under `../../hooks/user-level/`. Install it per-repo with the bundled installer —
> `setup.sh` does **not** symlink it.

## Why

Skills only help if they're loaded. Agents routinely start a workflow — `git commit`, a code review,
`playwright-cli` — without first reading the skill that documents how this repo wants it done.
skill-gate closes that gap with two lightweight nudges:

- **Prompt reminders** — when your message looks like the start of a gated workflow, the agent gets
  a one-time reminder to load the skill.
- **Tool blocks** — when the agent tries to run a gated command (or MCP action) before loading the
  skill, the call is denied with a message telling it which skill to load first.

The hook **fails open**: if the manifest is missing or malformed, or a regex is invalid, nothing is
blocked.

## How it works

1. **Prompt submission** — a gate with `prompt_match` + `remind_message` injects a reminder (once per
   session/agent/skill).
2. **Skill load** — when the agent loads a tracked skill (via the Skill tool, a Claude prompt
   expansion, or a Copilot `read_file` of the exact `skills/<skill>/SKILL.md`), a per-session
   *receipt* is written.
3. **Tool use** — a gate with `tool_match` or `mcp_match` **blocks** the matching action until a
   skill-load receipt exists. Once the skill is loaded, the block (and the reminder) are suppressed
   for the rest of that session.

Receipts are small marker files under the OS temp dir (`<tmp>/claude-hooks/`), keyed by
session · agent · skill.

## Layout

```
skill-gate/
├─ install.mjs                         # cross-platform installer (pure Node)
├─ package.json                        # `npm test`
├─ .claude/hooks/
│  ├─ skill-gate-core.mjs              # shared engine: manifest load, matching, receipts, decisions
│  ├─ skill-gate.mjs                   # Claude Code adapter
│  ├─ skill-gates.json                 # the manifest — the gates you edit
│  ├─ skill-gate.md                    # manifest schema + authoring guide
│  └─ __tests__/                       # node:test suite (+ fixtures)
└─ .github/hooks/
   └─ skill-gate-copilot.mjs           # GitHub Copilot CLI adapter
```

Both adapters normalize their host's hook payload and delegate every decision to
`skill-gate-core.mjs`, so behavior stays identical across agents.

## Install

From this folder, install into any target repo (defaults to the current directory):

```bash
# into the current repo
node install.mjs

# into a specific repo, preview first
node install.mjs /path/to/repo --dry-run
node install.mjs /path/to/repo

# also copy the test suite into the target
node install.mjs /path/to/repo --with-tests
```

Standalone (no need to keep the repo around):

```bash
git clone https://github.com/DavidTeju/shared-skills.git /tmp/shared-skills
node /tmp/shared-skills/project-hooks/skill-gate/install.mjs /path/to/repo
rm -rf /tmp/shared-skills
```

The installer:

- copies the runtime files into `<target>/.claude/hooks` and `<target>/.github/hooks`,
- registers the Claude adapter in `<target>/.claude/settings.json`
  (`UserPromptSubmit`, `PreToolUse` for `Bash` and `mcp__.*`, `PostToolUse` for `Skill`,
  `UserPromptExpansion`),
- merges the Copilot adapter into `<target>/.github/hooks/hooks.json`.

It's **idempotent** — re-run any time to update. Restart the agent session afterwards so it reloads
the hooks.

## Shipped gates

The default [`skill-gates.json`](.claude/hooks/skill-gates.json) references skills that live in this
repo's `skills/` folder:

| Skill                  | Reminder (prompt)                          | Block (tool)          |
| ---------------------- | ------------------------------------------ | --------------------- |
| `git-commit-practices` | "commit these changes", "git commit"       | `git commit`          |
| `code-review`          | "code review", "review my PR", "find bugs" | —                     |
| `playwright-cli`       | —                                          | `playwright-cli`      |
| `update-readme`        | "update the readme", "sync docs"           | —                     |
| `create-cli-skill`     | "create a skill for …", "new cli skill"    | —                     |

Edit that file to fit your repo — gates are just data.

## Adding or editing a gate

A gate names a skill and one or more triggers:

```jsonc
{
  "skill": "git-commit-practices",           // must match a loadable skill (a folder under skills/)
  "prompt_match": { "regex": "\\bgit\\s+commit\\b" },
  "remind_message": "Load the git-commit-practices skill first …",
  "tool_match": { "command_regex": "\\bgit\\s+commit\\b" },
  "block_message": "About to run git commit. Load git-commit-practices first."
}
```

- `prompt_match` + `remind_message` → a one-time reminder on matching prompts.
- `tool_match` → block matching shell commands.
- `mcp_match` (`{ tools: [...], input_match?: {...} }`) → block matching MCP tool calls.

Gates are evaluated top-to-bottom; the first match wins. Full schema and authoring notes:
[`.claude/hooks/skill-gate.md`](.claude/hooks/skill-gate.md).

If you add an `mcp_match` gate for Claude Code, make sure the MCP tool name is covered by a
`PreToolUse` matcher in `.claude/settings.json` (the installer registers the catch-all `mcp__.*`).

## Testing

```bash
npm test
# or
node --test .claude/hooks/__tests__/*.test.mjs
```

The suite covers the engine (matching, receipts, decisions), both adapters' payload normalization,
and end-to-end block/reminder output from the spawned Copilot hook. The core suite validates the
shipped `skill-gates.json` directly, so a broken gate fails a test.

## Notes

- Pure Node, no dependencies — runs the same on Windows, macOS, and Linux.
- Reminders are shown once per session/agent/skill; **blocks repeat** until the skill is loaded.
- Fails open on any error, so a bad manifest can never wedge your session.
