import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, rmSync } from 'node:fs';
import { normalizeCopilotEvent } from '../../../.github/hooks/skill-gate-copilot.mjs';
import { receiptPath } from '../skill-gate-core.mjs';
import { fx } from './_helpers.mjs';

function runCopilotHook(eventName, payload) {
  return spawnSync(process.execPath, ['.github/hooks/skill-gate-copilot.mjs', eventName], {
    cwd: process.cwd(),
    encoding: 'utf8',
    input: JSON.stringify(payload),
  });
}

function clearReceipt(kind, agentKey, skill) {
  rmSync(receiptPath(kind, agentKey, skill), { force: true });
}

// ── normalizeCopilotEvent: payload parsing ───────────────────────────────────

test('Copilot bash preToolUse → command from double-decoded toolArgs', () => {
  const evt = normalizeCopilotEvent('preToolUse', fx('copilot-pretooluse-bash.json'));
  assert.equal(evt.event, 'PreToolUse');
  assert.equal(evt.toolName, 'bash');
  assert.equal(evt.command, 'git commit -m foo');
  assert.equal(evt.agentKey, '3ffa08e8-5940-4a1b-af29-1625433f4673');
});

test('Copilot subagent context → agentKey = call_* sessionId', () => {
  const evt = normalizeCopilotEvent('preToolUse', fx('copilot-pretooluse-subagent.json'));
  assert.equal(evt.agentKey, 'call_D5jIWYsQB8Plxnm6e4C0aBxq');
  assert.equal(evt.command, 'git commit -m from-subagent');
  assert.equal(evt.toolName, 'powershell');
});

test('Copilot preToolUse from hook payload → command from snake_case tool_input', () => {
  const evt = normalizeCopilotEvent('preToolUse', {
    session_id: 'e1d21c21-0bc2-4308-8bae-dc08a9dace79',
    tool_name: 'run_in_terminal',
    tool_input: JSON.stringify({ command: 'git commit --amend' }),
  });
  assert.equal(evt.event, 'PreToolUse');
  assert.equal(evt.agentKey, 'e1d21c21-0bc2-4308-8bae-dc08a9dace79');
  assert.equal(evt.toolName, 'run_in_terminal');
  assert.equal(evt.command, 'git commit --amend');
});

test('Copilot MCP preToolUse → mcpTool and mcpInput from decoded toolArgs', () => {
  const evt = normalizeCopilotEvent('preToolUse', {
    sessionId: 's',
    toolName: 'mcp__notion__API-patch-page',
    toolArgs: JSON.stringify({ action: 'update' }),
  });
  assert.equal(evt.mcpTool, 'mcp__notion__API-patch-page');
  assert.deepEqual(evt.mcpInput, { action: 'update' });
});

test('Copilot userPromptSubmitted → event mapped, prompt populated', () => {
  const evt = normalizeCopilotEvent('userPromptSubmitted', fx('copilot-userpromptsubmitted.json'));
  assert.equal(evt.event, 'UserPromptSubmit');
  assert.equal(evt.prompt, 'commit these changes');
});

test('Copilot userPromptSubmitted from hook payload → agentKey from snake_case session_id', () => {
  const evt = normalizeCopilotEvent('userPromptSubmitted', {
    session_id: 'e1d21c21-0bc2-4308-8bae-dc08a9dace79',
    prompt: 'commit these changes without loading the skill',
  });
  assert.equal(evt.event, 'UserPromptSubmit');
  assert.equal(evt.agentKey, 'e1d21c21-0bc2-4308-8bae-dc08a9dace79');
  assert.equal(evt.prompt, 'commit these changes without loading the skill');
});

test('Copilot agentStop → Stop, subagentStop → SubagentStop, sessionEnd → Stop', () => {
  assert.equal(normalizeCopilotEvent('agentStop', { sessionId: 's' }).event, 'Stop');
  assert.equal(normalizeCopilotEvent('subagentStop', { sessionId: 's' }).event, 'SubagentStop');
  assert.equal(normalizeCopilotEvent('sessionEnd', { sessionId: 's' }).event, 'Stop');
});

test('Copilot postToolUse Skill → skillName from decoded toolArgs', () => {
  const evt = normalizeCopilotEvent('postToolUse', {
    sessionId: 's',
    toolName: 'Skill',
    toolArgs: JSON.stringify({ skill: 'git-commit-practices' }),
  });
  assert.equal(evt.event, 'PostToolUse');
  assert.equal(evt.toolName, 'Skill');
  assert.equal(evt.skillName, 'git-commit-practices');
});

test('Copilot postToolUse lowercase skill → skillName from decoded toolArgs', () => {
  const evt = normalizeCopilotEvent('postToolUse', {
    sessionId: 's',
    toolName: 'skill',
    toolArgs: JSON.stringify({ skill: 'git-commit-practices' }),
  });
  assert.equal(evt.event, 'PostToolUse');
  assert.equal(evt.toolName, 'skill');
  assert.equal(evt.skillName, 'git-commit-practices');
});

test('Copilot postToolUse read_file of repo skill → skillName from SKILL.md path', () => {
  const evt = normalizeCopilotEvent('postToolUse', {
    sessionId: 's',
    toolName: 'read_file',
    toolArgs: JSON.stringify({ filePath: `${process.cwd()}/.claude/skills/git-commit-practices/SKILL.md` }),
  });
  assert.equal(evt.event, 'PostToolUse');
  assert.equal(evt.toolName, 'read_file');
  assert.equal(evt.skillName, 'git-commit-practices');
});

test('Copilot postToolUse read_file ignores skill-shaped paths outside the repo', () => {
  const evt = normalizeCopilotEvent('postToolUse', {
    sessionId: 's',
    toolName: 'read_file',
    toolArgs: JSON.stringify({ filePath: '/tmp/.claude/skills/git-commit-practices/SKILL.md' }),
  });
  assert.equal(evt.skillName, null);
});

test('Copilot adapter tolerates malformed toolArgs (no throw)', () => {
  const evt = normalizeCopilotEvent('preToolUse', { sessionId: 's', toolName: 'bash', toolArgs: 'not json' });
  assert.equal(evt.command, null);
  assert.equal(evt.mcpInput, null);
});

// ── End-to-end via the spawned Copilot hook ──────────────────────────────────

test('Copilot preToolUse block emits top-level permission decision', () => {
  const result = runCopilotHook('preToolUse', {
    sessionId: 'copilot-block-output-test',
    timestamp: 1779907700000,
    cwd: process.cwd(),
    toolName: 'bash',
    toolArgs: JSON.stringify({ command: 'git commit -m wip' }),
  });

  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(JSON.parse(result.stdout), {
    permissionDecision: 'deny',
    permissionDecisionReason:
      'About to run git commit. Load the git-commit-practices skill via the Skill tool first — it enforces atomic commits and meaningful messages.',
    hookSpecificOutput: {
      hookEventName: 'PreToolUse',
      permissionDecision: 'deny',
      permissionDecisionReason:
        'About to run git commit. Load the git-commit-practices skill via the Skill tool first — it enforces atomic commits and meaningful messages.',
    },
  });
});

test('Copilot userPromptSubmitted reminders emit additional context and write receipts', () => {
  const sessionId = 'copilot-remind-output-test';
  clearReceipt('reminded', sessionId, 'git-commit-practices');

  try {
    const result = runCopilotHook('userPromptSubmitted', {
      sessionId,
      timestamp: 1779907680860,
      cwd: process.cwd(),
      prompt: 'commit these changes',
    });

    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(JSON.parse(result.stdout), {
      hookSpecificOutput: {
        hookEventName: 'UserPromptSubmit',
        additionalContext:
          '[skill-gate] About to work on a git commit. Load the `git-commit-practices` skill first — it covers atomic commits, meaningful messages, and what not to commit.',
      },
    });
    assert.equal(existsSync(receiptPath('reminded', sessionId, 'git-commit-practices')), true);
  } finally {
    clearReceipt('reminded', sessionId, 'git-commit-practices');
  }
});

test('Copilot postToolUse record keeps writing loaded receipts without stdout', () => {
  const sessionId = 'copilot-record-output-test';
  clearReceipt('loaded', sessionId, 'git-commit-practices');

  try {
    const result = runCopilotHook('postToolUse', {
      sessionId,
      timestamp: 1779907680860,
      cwd: process.cwd(),
      toolName: 'Skill',
      toolArgs: JSON.stringify({ skill: 'git-commit-practices' }),
    });

    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.stdout, '');
    assert.equal(existsSync(receiptPath('loaded', sessionId, 'git-commit-practices')), true);
  } finally {
    clearReceipt('loaded', sessionId, 'git-commit-practices');
  }
});

test('Copilot postToolUse lowercase skill record writes loaded receipts', () => {
  const sessionId = 'copilot-lowercase-skill-record-test';
  clearReceipt('loaded', sessionId, 'git-commit-practices');

  try {
    const result = runCopilotHook('postToolUse', {
      sessionId,
      timestamp: 1779907680860,
      cwd: process.cwd(),
      toolName: 'skill',
      toolArgs: JSON.stringify({ skill: 'git-commit-practices' }),
    });

    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.stdout, '');
    assert.equal(existsSync(receiptPath('loaded', sessionId, 'git-commit-practices')), true);
  } finally {
    clearReceipt('loaded', sessionId, 'git-commit-practices');
  }
});
