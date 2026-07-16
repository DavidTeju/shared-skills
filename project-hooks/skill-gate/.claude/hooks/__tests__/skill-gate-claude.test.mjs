import test from 'node:test';
import assert from 'node:assert/strict';
import { normalizeClaudeEvent } from '../skill-gate.mjs';
import { fx } from './_helpers.mjs';

test('Claude Bash PreToolUse → toolName=Bash, command, agentKey=session-main', () => {
  const evt = normalizeClaudeEvent(fx('claude-pretooluse-bash.json'));
  assert.equal(evt.event, 'PreToolUse');
  assert.equal(evt.toolName, 'Bash');
  assert.equal(evt.command, "git commit -m 'add auth'");
  assert.equal(evt.mcpTool, null);
  assert.equal(evt.agentKey, '11111111-2222-3333-4444-555555555555-main');
});

test('Claude MCP PreToolUse → mcpTool + mcpInput populated', () => {
  const evt = normalizeClaudeEvent(fx('claude-pretooluse-mcp.json'));
  assert.equal(evt.mcpTool, 'mcp__notion__API-patch-page');
  assert.equal(evt.mcpInput.action, 'update');
  assert.equal(evt.command, null);
});

test('Claude Skill PostToolUse → skillName from tool_input.skill', () => {
  const evt = normalizeClaudeEvent(fx('claude-posttooluse-skill.json'));
  assert.equal(evt.event, 'PostToolUse');
  assert.equal(evt.toolName, 'Skill');
  assert.equal(evt.skillName, 'git-commit-practices');
});

test('Claude UserPromptSubmit → prompt populated', () => {
  const evt = normalizeClaudeEvent(fx('claude-userpromptsubmit.json'));
  assert.equal(evt.event, 'UserPromptSubmit');
  assert.equal(evt.prompt, 'please review my branch for bugs');
});

test('Claude SubagentStop → agentKey composes session+agent_id', () => {
  const evt = normalizeClaudeEvent(fx('claude-subagentstop.json'));
  assert.equal(evt.event, 'SubagentStop');
  assert.equal(evt.agentKey, '11111111-2222-3333-4444-555555555555-agent_sub_1');
});

test('Claude UserPromptExpansion → skillName from command field', () => {
  const evt = normalizeClaudeEvent({
    hook_event_name: 'UserPromptExpansion',
    session_id: 's',
    command: 'git-commit-practices',
  });
  assert.equal(evt.event, 'UserPromptExpansion');
  assert.equal(evt.skillName, 'git-commit-practices');
});
