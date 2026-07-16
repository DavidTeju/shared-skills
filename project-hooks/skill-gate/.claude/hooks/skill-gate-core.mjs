import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';

const RECEIPT_ROOT = path.join(os.tmpdir(), 'claude-hooks');

export function receiptPath(kind, agentKey, skill) {
  return path.join(RECEIPT_ROOT, `skill-${kind}-${agentKey}-${skill}`);
}

export function hasReceipt(kind, agentKey, skill) {
  try {
    return fs.existsSync(receiptPath(kind, agentKey, skill));
  } catch {
    return false;
  }
}

export function writeReceipt(kind, agentKey, skill) {
  fs.mkdirSync(RECEIPT_ROOT, { recursive: true });
  fs.writeFileSync(receiptPath(kind, agentKey, skill), String(Date.now()));
}

const EMPTY_MANIFEST = Object.freeze({ version: 1, gates: [] });

export function loadManifest(manifestPath) {
  try {
    const raw = fs.readFileSync(manifestPath, 'utf8');
    const parsed = JSON.parse(raw);
    if (!parsed || !Array.isArray(parsed.gates)) return EMPTY_MANIFEST;
    return parsed;
  } catch (err) {
    if (err && err.code !== 'ENOENT') {
      process.stderr.write(`[skill-gate] manifest load failed: ${err.message}\n`);
    }
    return EMPTY_MANIFEST;
  }
}

export function matchPrompt(gate, prompt) {
  if (!gate || !gate.prompt_match || typeof prompt !== 'string') return false;
  const flags = gate.prompt_match.case_sensitive === true ? '' : 'i';
  try {
    return new RegExp(gate.prompt_match.regex, flags).test(prompt);
  } catch {
    return false;
  }
}

export function matchCommand(gate, command) {
  if (!gate || !gate.tool_match || typeof command !== 'string') return false;
  const { command_regex, case_sensitive } = gate.tool_match;
  if (typeof command_regex !== 'string') return false;
  const flags = case_sensitive === true ? '' : 'i';
  try {
    return new RegExp(command_regex, flags).test(command);
  } catch {
    return false;
  }
}

export function matchMcp(gate, mcpTool, mcpInput) {
  if (!gate || !gate.mcp_match || typeof mcpTool !== 'string') return false;
  const { tools, input_match } = gate.mcp_match;
  if (!Array.isArray(tools) || !tools.includes(mcpTool)) return false;
  if (input_match && typeof input_match === 'object') {
    if (!mcpInput || typeof mcpInput !== 'object') return false;
    for (const [k, v] of Object.entries(input_match)) {
      if (mcpInput[k] !== v) return false;
    }
  }
  return true;
}

export function decide(evt, manifestPath) {
  const manifest = loadManifest(manifestPath);

  if (evt.event === 'PostToolUse' || evt.event === 'UserPromptExpansion') {
    if (typeof evt.skillName === 'string') {
      const tracked = manifest.gates.some((g) => g.skill === evt.skillName);
      if (tracked) return { action: 'record', kind: 'loaded', skill: evt.skillName };
    }
    return { action: 'allow' };
  }

  if (evt.event === 'UserPromptSubmit') {
    for (const gate of manifest.gates) {
      if (!gate.prompt_match || !gate.remind_message) continue;
      if (!matchPrompt(gate, evt.prompt)) continue;
      if (hasReceipt('reminded', evt.agentKey, gate.skill)) continue;
      if (hasReceipt('loaded', evt.agentKey, gate.skill)) continue;
      return { action: 'remind', skill: gate.skill, message: gate.remind_message };
    }
    return { action: 'allow' };
  }

  if (evt.event === 'PreToolUse') {
    for (const gate of manifest.gates) {
      const hitShell = matchCommand(gate, evt.command);
      const hitMcp = matchMcp(gate, evt.mcpTool, evt.mcpInput);
      if (!hitShell && !hitMcp) continue;
      if (hasReceipt('loaded', evt.agentKey, gate.skill)) continue;
      const message = gate.block_message ||
        `About to perform an action covered by the ${gate.skill} skill. Load it via the Skill tool first.`;
      return { action: 'block', skill: gate.skill, message };
    }
    return { action: 'allow' };
  }

  return { action: 'allow' };
}

export async function readStdin() {
  return await new Promise((resolve) => {
    let buf = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (c) => (buf += c));
    process.stdin.on('end', () => resolve(buf));
    process.stdin.on('error', () => resolve(''));
  });
}

export function emitDecision(d, evt) {
  switch (d.action) {
    case 'allow':
      process.exit(0);
      return;
    case 'remind':
      process.stdout.write(JSON.stringify({
        hookSpecificOutput: {
          hookEventName: 'UserPromptSubmit',
          additionalContext: d.message,
        },
      }));
      writeReceipt('reminded', evt.agentKey, d.skill);
      process.exit(0);
      return;
    case 'block':
      process.stdout.write(JSON.stringify({
        permissionDecision: 'deny',
        permissionDecisionReason: d.message,
        hookSpecificOutput: {
          hookEventName: 'PreToolUse',
          permissionDecision: 'deny',
          permissionDecisionReason: d.message,
        },
      }));
      process.exit(0);
      return;
    case 'record':
      writeReceipt(d.kind, evt.agentKey, d.skill);
      process.exit(0);
      return;
  }
}
