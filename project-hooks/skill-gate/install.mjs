#!/usr/bin/env node
// install.mjs — Install the skill-gate hook system into a target repository.
//
// Copies the runtime files into <target>/.claude/hooks and <target>/.github/hooks,
// registers the Claude adapter in <target>/.claude/settings.json, and merges the
// Copilot adapter into <target>/.github/hooks/hooks.json. Pure Node — no bash,
// python, or external deps — so it runs the same on Windows, macOS, and Linux.
//
// Usage:
//   node install.mjs [targetRepo] [--dry-run] [--with-tests]
//
//   targetRepo    Path to the repo to install into (default: current directory)
//   --dry-run     Print what would change without writing anything
//   --with-tests  Also copy the __tests__ folder (node --test suite)
//   -h, --help    Show this help

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const SRC_ROOT = path.dirname(fileURLToPath(import.meta.url));

const CLAUDE_HOOKS = [
    ".claude/hooks/skill-gate-core.mjs",
    ".claude/hooks/skill-gate.mjs",
    ".claude/hooks/skill-gates.json",
    ".claude/hooks/skill-gate.md",
];
const COPILOT_HOOK = ".github/hooks/skill-gate-copilot.mjs";
const TESTS_DIR = ".claude/hooks/__tests__";

// Claude settings.json registrations. The command mirrors Claude Code's project
// hook convention ($CLAUDE_PROJECT_DIR resolves to the repo root at runtime).
const CLAUDE_COMMAND = 'node "${CLAUDE_PROJECT_DIR:-.}/.claude/hooks/skill-gate.mjs"';
const CLAUDE_REGISTRATIONS = [
    { event: "UserPromptSubmit", matcher: "" },
    { event: "PreToolUse", matcher: "Bash" },
    { event: "PreToolUse", matcher: "mcp__.*" },
    { event: "PostToolUse", matcher: "Skill" },
    { event: "UserPromptExpansion", matcher: "" },
];

// Copilot hooks.json registrations.
const COPILOT_EVENTS = ["userPromptSubmitted", "preToolUse", "postToolUse"];

function parseArgs(argv) {
    const opts = { target: null, dryRun: false, withTests: false, help: false };
    for (const arg of argv) {
        if (arg === "--dry-run") opts.dryRun = true;
        else if (arg === "--with-tests") opts.withTests = true;
        else if (arg === "-h" || arg === "--help") opts.help = true;
        else if (!arg.startsWith("-") && opts.target === null) opts.target = arg;
    }
    return opts;
}

const HELP = `install.mjs — install the skill-gate hook system into a target repo

Usage:
  node install.mjs [targetRepo] [--dry-run] [--with-tests]

  targetRepo    Path to the repo to install into (default: current directory)
  --dry-run     Print what would change without writing anything
  --with-tests  Also copy the __tests__ folder (node --test suite)
  -h, --help    Show this help`;

function log(msg) {
    process.stdout.write(msg + "\n");
}

function readJson(file) {
    if (!fs.existsSync(file)) return null;
    try {
        return JSON.parse(fs.readFileSync(file, "utf8"));
    } catch {
        return null; // treat malformed like missing — we rebuild it
    }
}

function copyFile(relPath, target, dryRun) {
    const src = path.join(SRC_ROOT, relPath);
    const dst = path.join(target, relPath);
    if (!fs.existsSync(src)) {
        log(`  SKIP ${relPath} (not found in source)`);
        return;
    }
    if (dryRun) {
        log(`  WOULD COPY ${relPath}`);
        return;
    }
    fs.mkdirSync(path.dirname(dst), { recursive: true });
    fs.copyFileSync(src, dst);
    log(`  ✓ ${relPath}`);
}

function copyDir(relDir, target, dryRun) {
    const src = path.join(SRC_ROOT, relDir);
    if (!fs.existsSync(src)) {
        log(`  SKIP ${relDir} (not found in source)`);
        return;
    }
    for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
        const childRel = `${relDir}/${entry.name}`;
        if (entry.isDirectory()) copyDir(childRel, target, dryRun);
        else copyFile(childRel, target, dryRun);
    }
}

// ── Claude settings.json ─────────────────────────────────────────────────────

function registerClaude(target, dryRun) {
    const settingsFile = path.join(target, ".claude/settings.json");
    const settings = readJson(settingsFile) ?? {};
    const hooks = (settings.hooks ??= {});
    let changed = false;

    for (const { event, matcher } of CLAUDE_REGISTRATIONS) {
        const groups = (hooks[event] ??= []);
        const already = groups.some(
            (g) => (g.matcher ?? "") === matcher && (g.hooks ?? []).some((h) => h.command === CLAUDE_COMMAND),
        );
        if (already) {
            log(`  = ${event}${matcher ? ` [${matcher}]` : ""} already registered`);
            continue;
        }
        const group = { hooks: [{ type: "command", command: CLAUDE_COMMAND }] };
        if (matcher) group.matcher = matcher;
        groups.push(group);
        changed = true;
        log(`  ✓ ${event}${matcher ? ` [${matcher}]` : ""}`);
    }

    if (!changed) return;
    if (dryRun) {
        log(`  WOULD WRITE ${path.relative(target, settingsFile) || settingsFile}`);
        return;
    }
    fs.mkdirSync(path.dirname(settingsFile), { recursive: true });
    fs.writeFileSync(settingsFile, JSON.stringify(settings, null, 4) + "\n");
}

// ── Copilot .github/hooks/hooks.json ─────────────────────────────────────────

function registerCopilot(target, dryRun) {
    const hooksFile = path.join(target, ".github/hooks/hooks.json");
    const doc = readJson(hooksFile) ?? { version: 1, hooks: {} };
    doc.version ??= 1;
    doc.hooks ??= {};
    let changed = false;

    for (const event of COPILOT_EVENTS) {
        const command = `node .github/hooks/skill-gate-copilot.mjs ${event}`;
        const entries = (doc.hooks[event] ??= []);
        const already = entries.some((e) => e.bash === command || e.powershell === command);
        if (already) {
            log(`  = ${event} already registered`);
            continue;
        }
        entries.push({ type: "command", bash: command, powershell: command, timeoutSec: 5 });
        changed = true;
        log(`  ✓ ${event}`);
    }

    if (!changed) return;
    if (dryRun) {
        log(`  WOULD WRITE ${path.relative(target, hooksFile) || hooksFile}`);
        return;
    }
    fs.mkdirSync(path.dirname(hooksFile), { recursive: true });
    fs.writeFileSync(hooksFile, JSON.stringify(doc, null, 4) + "\n");
}

// ── main ─────────────────────────────────────────────────────────────────────

function main() {
    const opts = parseArgs(process.argv.slice(2));
    if (opts.help) {
        log(HELP);
        return;
    }

    const target = path.resolve(opts.target ?? process.cwd());
    if (!fs.existsSync(target)) {
        process.stderr.write(`ERROR: target repo does not exist: ${target}\n`);
        process.exit(1);
    }

    log(`Installing skill-gate → ${target}${opts.dryRun ? "  (dry run)" : ""}\n`);

    log("Runtime files:");
    for (const f of CLAUDE_HOOKS) copyFile(f, target, opts.dryRun);
    copyFile(COPILOT_HOOK, target, opts.dryRun);
    if (opts.withTests) {
        log("\nTest suite:");
        copyDir(TESTS_DIR, target, opts.dryRun);
    }

    log("\nClaude registration → .claude/settings.json");
    registerClaude(target, opts.dryRun);

    log("\nCopilot registration → .github/hooks/hooks.json");
    registerCopilot(target, opts.dryRun);

    log("");
    if (opts.dryRun) log("Dry run complete. Re-run without --dry-run to apply.");
    else log("Done. Restart the agent session so it picks up the hooks.");
}

main();
