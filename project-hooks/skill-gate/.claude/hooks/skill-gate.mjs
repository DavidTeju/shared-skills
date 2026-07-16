#!/usr/bin/env node
import { decide, readStdin, emitDecision } from './skill-gate-core.mjs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const MANIFEST = path.join(process.env.CLAUDE_PROJECT_DIR || process.cwd(), '.claude/hooks/skill-gates.json');

function extractSkillName(event, toolName, toolInput, payload) {
  if (toolName === 'Skill' && typeof toolInput.skill === 'string') return toolInput.skill;
  if (event === 'UserPromptExpansion' && typeof payload.command === 'string') return payload.command;
  return null;
}

export function normalizeClaudeEvent(payload) {
  const event = payload.hook_event_name || null;
  const sessionId = payload.session_id || 'unknown';
  const agentId = payload.agent_id || null;
  const toolName = payload.tool_name || null;
  const toolInput = payload.tool_input || {};
  const isMcp = typeof toolName === 'string' && toolName.startsWith('mcp__');

  return {
    event,
    agentKey: `${sessionId}-${agentId || 'main'}`,
    toolName,
    command: typeof toolInput.command === 'string' ? toolInput.command : null,
    mcpTool: isMcp ? toolName : null,
    mcpInput: isMcp ? toolInput : null,
    skillName: extractSkillName(event, toolName, toolInput, payload),
    prompt: typeof payload.prompt === 'string' ? payload.prompt : null,
  };
}

async function main() {
  const raw = await readStdin();
  let payload;
  try { payload = JSON.parse(raw); } catch {
    process.stderr.write('[skill-gate] non-JSON payload, skipping\n');
    process.exit(0);
  }
  const evt = normalizeClaudeEvent(payload);
  const decision = decide(evt, MANIFEST);
  emitDecision(decision, evt);
}

const isDirectInvocation = process.argv[1] ? import.meta.url === pathToFileURL(process.argv[1]).href : false;
if (isDirectInvocation) {
  main().catch((err) => {
    process.stderr.write(`[skill-gate] unhandled error: ${err.message}\n`);
    process.exit(0);
  });
}
