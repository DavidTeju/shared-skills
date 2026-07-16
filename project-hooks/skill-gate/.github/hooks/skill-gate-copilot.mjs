#!/usr/bin/env node
import { decide, readStdin, emitDecision } from "../../.claude/hooks/skill-gate-core.mjs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const MANIFEST = path.join(process.cwd(), ".claude/hooks/skill-gates.json");
const REPO_SKILL_ROOTS = [path.join(process.cwd(), ".claude/skills"), path.join(process.cwd(), ".github/skills")];

const COPILOT_EVENT_MAP = {
  preToolUse: "PreToolUse",
  postToolUse: "PostToolUse",
  userPromptSubmitted: "UserPromptSubmit",
  agentStop: "Stop",
  subagentStop: "SubagentStop",
  sessionEnd: "Stop",
};

function parseToolArgs(raw) {
  if (raw == null) return null;
  if (typeof raw === "object") return raw;
  if (typeof raw !== "string") return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function payloadValue(payload, camelKey, snakeKey) {
  return payload[camelKey] ?? payload[snakeKey];
}

function skillNameFromSkillTool(toolName, decodedArgs) {
  if (typeof toolName !== "string") return null;
  const normalizedToolName = toolName.toLowerCase();
  if (normalizedToolName !== "skill" && normalizedToolName !== "functions.skill") return null;
  if (!decodedArgs || typeof decodedArgs !== "object") return null;
  return typeof decodedArgs.skill === "string" ? decodedArgs.skill : null;
}

function comparablePath(rawPath) {
  if (typeof rawPath !== "string") return null;
  let filePath = rawPath;
  if (filePath.startsWith("file://")) {
    try {
      filePath = fileURLToPath(filePath);
    } catch {
      return null;
    }
  }
  return path.resolve(filePath).replace(/\\/g, "/");
}

function skillNameFromReadFile(toolName, decodedArgs) {
  if (toolName !== "read_file" && toolName !== "functions.read_file") return null;
  if (!decodedArgs || typeof decodedArgs !== "object") return null;
  const skillPath = comparablePath(decodedArgs.filePath ?? decodedArgs.file_path ?? decodedArgs.path);
  if (!skillPath || !skillPath.endsWith("/SKILL.md")) return null;

  for (const root of REPO_SKILL_ROOTS) {
    const skillRoot = comparablePath(root);
    if (!skillRoot || !skillPath.startsWith(`${skillRoot}/`)) continue;
    const relativePath = skillPath.slice(skillRoot.length + 1);
    const parts = relativePath.split("/");
    if (parts.length === 2 && parts[0] && parts[1] === "SKILL.md") return parts[0];
  }

  return null;
}

export function normalizeCopilotEvent(rawEventName, payload) {
  const event = COPILOT_EVENT_MAP[rawEventName] || null;
  const sessionId = payloadValue(payload, "sessionId", "session_id") || "unknown";
  const toolName = payloadValue(payload, "toolName", "tool_name") || null;
  const decodedArgs = parseToolArgs(payloadValue(payload, "toolArgs", "tool_input"));
  const isMcp = typeof toolName === "string" && toolName.startsWith("mcp__");

  return {
    event,
    agentKey: sessionId,
    toolName,
    command: decodedArgs && typeof decodedArgs.command === "string" ? decodedArgs.command : null,
    mcpTool: isMcp ? toolName : null,
    mcpInput: isMcp ? decodedArgs : null,
    skillName:
      skillNameFromSkillTool(toolName, decodedArgs) ??
      (event === "PostToolUse"
        ? skillNameFromReadFile(toolName, decodedArgs)
        : null),
    prompt: typeof payload.prompt === "string" ? payload.prompt : null,
  };
}

async function main() {
  const eventName = process.argv[2];
  if (!eventName) {
    process.stderr.write("[skill-gate-copilot] missing event name argv[2]\n");
    process.exit(0);
  }
  const raw = await readStdin();
  let payload;
  try {
    payload = raw ? JSON.parse(raw) : {};
  } catch {
    process.stderr.write("[skill-gate-copilot] non-JSON payload, skipping\n");
    process.exit(0);
  }
  const evt = normalizeCopilotEvent(eventName, payload);
  const decision = decide(evt, MANIFEST);
  emitDecision(decision, evt);
}

const isDirectInvocation = process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;
if (isDirectInvocation) {
  main().catch((err) => {
    process.stderr.write(`[skill-gate-copilot] unhandled error: ${err.message}\n`);
    process.exit(0);
  });
}
