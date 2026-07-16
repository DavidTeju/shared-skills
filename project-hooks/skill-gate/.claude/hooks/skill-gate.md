# Skill gate hooks

Skill gates remind agents to load required skills before starting workflows that have project-specific process rules. They also block tool calls that would perform gated actions before the matching skill has been loaded.

## Quick reference

| File                                   | Purpose                                                                                                                                           |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.claude/hooks/skill-gates.json`       | Canonical skill-gate manifest. This is the file that lists skills, prompt reminders, shell command matches, MCP tool matches, and block messages. |
| `.claude/hooks/skill-gate.mjs`         | Claude hook adapter. It normalizes Claude hook payloads and delegates decisions to the shared core.                                               |
| `.claude/hooks/skill-gate-core.mjs`    | Shared gate engine. It loads the manifest, matches prompt/tool/MCP events, writes skill-load receipts, and emits hook decisions.                  |
| `.github/hooks/skill-gate-copilot.mjs` | Copilot hook adapter. It normalizes Copilot hook payloads, delegates decisions to the shared core, and emits Copilot-native top-level output for `preToolUse` blocks. |
| `.github/hooks/hooks.json`             | Copilot hook registration manifest. It wires Copilot hook events to `skill-gate-copilot.mjs`; it is not the skill-gate rule manifest.             |

## Runtime behavior

1. On prompt submission, a gate with `prompt_match` and `remind_message` can add contextual guidance reminding the agent to load a skill.
2. When the agent loads a tracked skill through the Skill tool, a Claude prompt expansion, or a Copilot `read_file` of the repo's exact `*/skills/<skill>/SKILL.md`, the hook records a per-session receipt for that skill.
3. Before tool use, a gate with `tool_match` or `mcp_match` blocks matching actions unless the corresponding skill-load receipt exists.

Prompt reminders are shown once per session/agent/skill. Loading the skill suppresses both future reminders and future blocks for that same session/agent/skill. Receipts are stored under the operating system temp directory in a `claude-hooks` folder.

The hook fails open if the manifest is missing or malformed. Invalid regexes do not match.

## Manifest schema

The canonical manifest lives at `.claude/hooks/skill-gates.json`.

```js
{
  version: 1,                  // required  number   — always 1 for now
  gates: [                     // required  Gate[]   — evaluated top-to-bottom; first match wins
    {
      skill: "git-commit-practices",  // required  string   — exact name of the skill that must be loaded
                               //                      (must match a loadable skill; in this repo, a folder
                               //                       under skills/, e.g. git-commit-practices, code-review,
                               //                       playwright-cli, update-readme, create-cli-skill, …)

      // ── prompt reminder ──────────────────────────────────────────────────────────────────────
      // Fires on UserPromptSubmit. When the user's message looks like they're about to start a
      // gated workflow, inject a nudge before the agent responds — but only once per session.
      prompt_match?: {
        regex: "\\bgit\\s+commit\\b",  // required  JS regex string tested against the prompt text
        case_sensitive?: false,        // optional  default false — omit to get case-insensitive matching
      },
      remind_message?: "…",   // required when prompt_match is present
                               //           string   — appended to the prompt as additional context

      // ── tool block ───────────────────────────────────────────────────────────────────────────
      // Fires on PreToolUse. Blocks the action outright until the skill has been loaded.
      // A gate can have tool_match, mcp_match, or both — either hit triggers the block.
      tool_match?: {
        command_regex: "\\bgit\\s+commit\\b",  // required  JS regex tested against the shell command string
        case_sensitive?: false,                 // optional  default false
      },
      mcp_match?: {
        tools: ["mcp__notion__API-patch-page"],  // required  string[]  — exact MCP tool names
        input_match?: { action: "update" },       // optional  object    — shallow key=value filter
                                                  //                       on the tool's input payload;
                                                  //                       all listed pairs must match exactly
      },
      block_message?: "…",    // optional  string   — denial reason shown to the agent
                               //                      defaults to a generic "load <skill> first" message
    },

  ],
}
```

## Adding or updating a gate

1. Confirm the workflow is covered by an existing skill and use that exact skill name in `skill`.
2. Add `prompt_match` plus `remind_message` only when the user's prompt can be matched with high confidence.
3. Add `tool_match` for shell commands that perform the gated action.
4. Add `mcp_match` for MCP tools that perform the gated action, and use `input_match` to avoid blocking unrelated actions on the same tool.
5. Keep messages concise and action-oriented: name the skill and explain why it must be loaded.
6. Update the hook tests when changing canonical gates or matcher behavior.
