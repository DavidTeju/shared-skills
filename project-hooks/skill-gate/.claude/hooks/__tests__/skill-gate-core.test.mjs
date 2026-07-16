import test from "node:test";
import assert from "node:assert/strict";
import os from "node:os";
import path from "node:path";
import fs from "node:fs";
import {
    receiptPath, writeReceipt, hasReceipt,
    loadManifest, matchPrompt, matchCommand, matchMcp, decide,
} from "../skill-gate-core.mjs";

function tempManifest(obj) {
    const p = path.join(os.tmpdir(), `mf-${Date.now()}-${Math.random().toString(36).slice(2)}.json`);
    fs.writeFileSync(p, JSON.stringify(obj));
    return p;
}

// A self-contained manifest used by the decide() tests. It mirrors the shape of
// the shipped manifest: one prompt+command gate and one MCP gate.
const DECIDE_FIXTURE = {
    version: 1,
    gates: [
        {
            skill: "git-commit-practices",
            prompt_match: { regex: "\\b(commit\\s+(these|my|the|all)\\s+changes?|git\\s+commit)\\b" },
            remind_message: "Detected a git commit request.",
            tool_match: { command_regex: "\\bgit\\s+commit\\b" },
            block_message: "Load git-commit-practices first.",
        },
        {
            skill: "querying-and-updating-notion",
            mcp_match: { tools: ["mcp__notion__API-patch-page"], input_match: { action: "update" } },
            block_message: "Load the notion skill first.",
        },
    ],
};

const commitPromptGate = {
    skill: "git-commit-practices",
    prompt_match: { regex: "\\b(commit\\s+(these|my|the|all)\\s+changes?|git\\s+commit)\\b" },
};

// ── receiptPath / writeReceipt / hasReceipt ──────────────────────────────────

test("receiptPath composes kind/agentKey/skill into tmpdir/claude-hooks", () => {
    const p = receiptPath("loaded", "sess123-main", "git-commit-practices");
    assert.equal(p, path.join(os.tmpdir(), "claude-hooks", "skill-loaded-sess123-main-git-commit-practices"));
});

test("receiptPath isolates kinds (loaded vs reminded vs blocked)", () => {
    assert.notEqual(receiptPath("loaded", "k", "s"), receiptPath("reminded", "k", "s"));
    assert.notEqual(receiptPath("loaded", "k", "s"), receiptPath("blocked", "k", "s"));
});

test("receiptPath isolates skills", () => {
    assert.notEqual(receiptPath("loaded", "k", "git-commit-practices"), receiptPath("loaded", "k", "code-review"));
});

test("writeReceipt creates the file and hasReceipt reports true", () => {
    const key = `t-${Date.now()}-${Math.random().toString(36).slice(2)}`;
    assert.equal(hasReceipt("loaded", key, "git-commit-practices"), false);
    writeReceipt("loaded", key, "git-commit-practices");
    assert.equal(hasReceipt("loaded", key, "git-commit-practices"), true);
    fs.unlinkSync(receiptPath("loaded", key, "git-commit-practices"));
});

test("writeReceipt is idempotent", () => {
    const key = `t-${Date.now()}-${Math.random().toString(36).slice(2)}`;
    writeReceipt("loaded", key, "code-review");
    assert.doesNotThrow(() => writeReceipt("loaded", key, "code-review"));
    fs.unlinkSync(receiptPath("loaded", key, "code-review"));
});

test("hasReceipt returns false when receipt does not exist", () => {
    assert.equal(hasReceipt("loaded", "nonexistent", "nope"), false);
});

// ── loadManifest ─────────────────────────────────────────────────────────────

test("loadManifest returns parsed manifest from a valid file", () => {
    const tmp = path.join(os.tmpdir(), `manifest-${Date.now()}.json`);
    fs.writeFileSync(
        tmp,
        JSON.stringify({
            version: 1,
            gates: [{ skill: "git-commit-practices", tool_match: { command_regex: "git commit" }, block_message: "load it" }],
        }),
    );
    const m = loadManifest(tmp);
    assert.equal(m.version, 1);
    assert.equal(m.gates.length, 1);
    assert.equal(m.gates[0].skill, "git-commit-practices");
    fs.unlinkSync(tmp);
});

test("loadManifest returns empty manifest when file is missing", () => {
    const m = loadManifest(path.join(os.tmpdir(), "definitely-not-there.json"));
    assert.deepEqual(m, { version: 1, gates: [] });
});

test("loadManifest returns empty manifest when file is malformed", () => {
    const tmp = path.join(os.tmpdir(), `bad-${Date.now()}.json`);
    fs.writeFileSync(tmp, "{ not json");
    const m = loadManifest(tmp);
    assert.deepEqual(m, { version: 1, gates: [] });
    fs.unlinkSync(tmp);
});

// ── Canonical gates: validate the shipped skill-gates.json ───────────────────

const CANONICAL = loadManifest(path.join(process.cwd(), ".claude/hooks/skill-gates.json"));
const canonicalGate = (skill) => CANONICAL.gates.find((g) => g.skill === skill);

test("canonical git-commit-practices gate reminds on commit phrasing", () => {
    const g = canonicalGate("git-commit-practices");
    assert.equal(matchPrompt(g, "commit these changes"), true);
    assert.equal(matchPrompt(g, "please git commit this"), true);
    assert.equal(matchPrompt(g, "review the commit history"), false);
});

test("canonical git-commit-practices gate blocks git commit but not git status", () => {
    const g = canonicalGate("git-commit-practices");
    assert.equal(matchCommand(g, "git commit -m 'wip'"), true);
    assert.equal(matchCommand(g, "git commit --amend"), true);
    assert.equal(matchCommand(g, "git status"), false);
    assert.equal(matchCommand(g, "git committed the fix"), false);
});

test("canonical code-review gate reminds on review requests and has no tool block", () => {
    const g = canonicalGate("code-review");
    assert.equal(matchPrompt(g, "please do a code review"), true);
    assert.equal(matchPrompt(g, "review my PR"), true);
    assert.equal(matchPrompt(g, "find bugs in this module"), true);
    assert.equal(matchPrompt(g, "just merge it"), false);
    assert.equal(matchCommand(g, "anything at all"), false);
});

test("canonical playwright-cli gate blocks the CLI but not lookalikes", () => {
    const g = canonicalGate("playwright-cli");
    assert.equal(matchCommand(g, "playwright-cli open https://example.com"), true);
    assert.equal(matchCommand(g, "npx playwright test"), false);
    assert.equal(matchCommand(g, "my-playwright-cli-fork status"), false);
});

test("canonical update-readme gate reminds on doc-sync phrasing", () => {
    const g = canonicalGate("update-readme");
    assert.equal(matchPrompt(g, "can you update the readme"), true);
    assert.equal(matchPrompt(g, "the docs are stale"), true);
    assert.equal(matchPrompt(g, "update the config"), false);
});

test("canonical create-cli-skill gate reminds on skill-authoring phrasing", () => {
    const g = canonicalGate("create-cli-skill");
    assert.equal(matchPrompt(g, "create a skill for ripgrep"), true);
    assert.equal(matchPrompt(g, "write a skill for jq"), true);
    assert.equal(matchPrompt(g, "create a new component"), false);
});

// ── matchPrompt ──────────────────────────────────────────────────────────────

test("matchPrompt is case-insensitive by default", () => {
    assert.equal(matchPrompt(commitPromptGate, "COMMIT THESE CHANGES"), true);
    assert.equal(matchPrompt(commitPromptGate, "Git Commit"), true);
});

test("matchPrompt matches keyword variants", () => {
    assert.equal(matchPrompt(commitPromptGate, "please commit all changes now"), true);
    assert.equal(matchPrompt(commitPromptGate, "go ahead and git commit"), true);
});

test("matchPrompt returns false on non-matching text", () => {
    assert.equal(matchPrompt(commitPromptGate, "review the commit history"), false);
});

test("matchPrompt respects case_sensitive:true override", () => {
    const g = { skill: "s", prompt_match: { regex: "\\bFoo\\b", case_sensitive: true } };
    assert.equal(matchPrompt(g, "Foo bar"), true);
    assert.equal(matchPrompt(g, "foo bar"), false);
});

test("matchPrompt returns false when gate has no prompt_match", () => {
    assert.equal(matchPrompt({ skill: "x" }, "anything"), false);
});

test("matchPrompt returns false when prompt is null", () => {
    assert.equal(matchPrompt(commitPromptGate, null), false);
});

test("matchPrompt returns false on an invalid regex (fails closed)", () => {
    const g = { skill: "x", prompt_match: { regex: "(" } };
    assert.equal(matchPrompt(g, "anything"), false);
});

// ── matchCommand ─────────────────────────────────────────────────────────────

const commitToolGate = { skill: "git-commit-practices", tool_match: { command_regex: "\\bgit\\s+commit\\b" } };

test("matchCommand fires on git commit but not git status or git committed", () => {
    assert.equal(matchCommand(commitToolGate, "git commit -m wip"), true);
    assert.equal(matchCommand(commitToolGate, "git commit --amend --no-edit"), true);
    assert.equal(matchCommand(commitToolGate, "git status"), false);
    assert.equal(matchCommand(commitToolGate, "git committed already"), false);
});

const playwrightGate = { skill: "playwright-cli", tool_match: { command_regex: "(^|[\\s/&|;])playwright-cli(\\s|$)" } };

test("matchCommand fires on playwright-cli but not lookalikes", () => {
    assert.equal(matchCommand(playwrightGate, "playwright-cli open"), true);
    assert.equal(matchCommand(playwrightGate, "npx && playwright-cli screenshot"), true);
    assert.equal(matchCommand(playwrightGate, "my-playwright-cli-fork"), false);
    assert.equal(matchCommand(playwrightGate, "npx playwright test"), false);
});

test("matchCommand returns false when gate has no tool_match", () => {
    assert.equal(matchCommand({ skill: "x" }, "git commit"), false);
});

test("matchCommand returns false when command is null", () => {
    assert.equal(matchCommand(commitToolGate, null), false);
});

test("matchCommand returns false on an invalid regex (fails closed)", () => {
    const g = { skill: "x", tool_match: { command_regex: "(" } };
    assert.equal(matchCommand(g, "git commit"), false);
});

// ── matchMcp ─────────────────────────────────────────────────────────────────

const notionMcpGate = {
    skill: "querying-and-updating-notion",
    mcp_match: {
        tools: ["mcp__notion__API-patch-page"],
        input_match: { action: "update" },
    },
};

test("matchMcp fires when tool matches AND input_match equals tool_input", () => {
    assert.equal(matchMcp(notionMcpGate, "mcp__notion__API-patch-page", { action: "update", pageId: "x" }), true);
});

test("matchMcp does NOT fire on non-matching actions", () => {
    for (const action of ["read", "create", "query"]) {
        assert.equal(matchMcp(notionMcpGate, "mcp__notion__API-patch-page", { action }), false);
    }
});

test("matchMcp does NOT fire on a different MCP tool", () => {
    assert.equal(matchMcp(notionMcpGate, "mcp__notion__API-post-page", { action: "update" }), false);
});

test("matchMcp fires with tools predicate only", () => {
    const g = { skill: "x", mcp_match: { tools: ["mcp__foo__bar"] } };
    assert.equal(matchMcp(g, "mcp__foo__bar", { anything: true }), true);
});

test("matchMcp returns false when gate has no mcp_match", () => {
    assert.equal(matchMcp({ skill: "x" }, "mcp__foo__bar", {}), false);
});

test("matchMcp returns false when mcpTool is null", () => {
    assert.equal(matchMcp(notionMcpGate, null, { action: "update" }), false);
});

// ── decide: PreToolUse blocks ────────────────────────────────────────────────

test("decide → block on matching Bash command without loaded receipt", () => {
    const mf = tempManifest(DECIDE_FIXTURE);
    const d = decide(
        {
            event: "PreToolUse",
            agentKey: `t-${Date.now()}`,
            toolName: "Bash",
            command: "git commit -m wip",
            mcpTool: null,
            mcpInput: null,
            skillName: null,
            prompt: null,
        },
        mf,
    );
    assert.equal(d.action, "block");
    assert.equal(d.skill, "git-commit-practices");
    assert.match(d.message, /Load git-commit-practices first/);
    fs.unlinkSync(mf);
});

test("decide → allow when loaded receipt exists for the matched gate", () => {
    const mf = tempManifest(DECIDE_FIXTURE);
    const key = `t-${Date.now()}-loaded`;
    writeReceipt("loaded", key, "git-commit-practices");
    const d = decide(
        {
            event: "PreToolUse",
            agentKey: key,
            toolName: "Bash",
            command: "git commit -m wip",
            mcpTool: null,
            mcpInput: null,
            skillName: null,
            prompt: null,
        },
        mf,
    );
    assert.equal(d.action, "allow");
    fs.unlinkSync(receiptPath("loaded", key, "git-commit-practices"));
    fs.unlinkSync(mf);
});

test("decide → block on MCP gate with matching input_match", () => {
    const mf = tempManifest(DECIDE_FIXTURE);
    const d = decide(
        {
            event: "PreToolUse",
            agentKey: `t-${Date.now()}`,
            toolName: "mcp__notion__API-patch-page",
            command: null,
            mcpTool: "mcp__notion__API-patch-page",
            mcpInput: { action: "update" },
            skillName: null,
            prompt: null,
        },
        mf,
    );
    assert.equal(d.action, "block");
    assert.equal(d.skill, "querying-and-updating-notion");
    fs.unlinkSync(mf);
});

test("decide → allow on MCP gate when action does not match input_match", () => {
    const mf = tempManifest(DECIDE_FIXTURE);
    const d = decide(
        {
            event: "PreToolUse",
            agentKey: `t-${Date.now()}`,
            toolName: "mcp__notion__API-patch-page",
            command: null,
            mcpTool: "mcp__notion__API-patch-page",
            mcpInput: { action: "read" },
            skillName: null,
            prompt: null,
        },
        mf,
    );
    assert.equal(d.action, "allow");
    fs.unlinkSync(mf);
});

// ── decide: UserPromptSubmit reminders ───────────────────────────────────────

test("decide → remind on matching UserPromptSubmit with no reminded receipt", () => {
    const mf = tempManifest(DECIDE_FIXTURE);
    const d = decide(
        {
            event: "UserPromptSubmit",
            agentKey: `t-${Date.now()}`,
            toolName: null,
            command: null,
            mcpTool: null,
            mcpInput: null,
            skillName: null,
            prompt: "commit these changes please",
        },
        mf,
    );
    assert.equal(d.action, "remind");
    assert.equal(d.skill, "git-commit-practices");
    assert.match(d.message, /git commit request/);
    fs.unlinkSync(mf);
});

test("decide → allow on UserPromptSubmit when reminded receipt exists", () => {
    const mf = tempManifest(DECIDE_FIXTURE);
    const key = `t-${Date.now()}-rem`;
    writeReceipt("reminded", key, "git-commit-practices");
    const d = decide(
        {
            event: "UserPromptSubmit",
            agentKey: key,
            toolName: null,
            command: null,
            mcpTool: null,
            mcpInput: null,
            skillName: null,
            prompt: "git commit now",
        },
        mf,
    );
    assert.equal(d.action, "allow");
    fs.unlinkSync(receiptPath("reminded", key, "git-commit-practices"));
    fs.unlinkSync(mf);
});

test("decide → allow on UserPromptSubmit when loaded receipt for the gate exists", () => {
    const mf = tempManifest(DECIDE_FIXTURE);
    const key = `t-${Date.now()}-loaded-commit`;
    writeReceipt("loaded", key, "git-commit-practices");
    const d = decide(
        {
            event: "UserPromptSubmit",
            agentKey: key,
            toolName: null,
            command: null,
            mcpTool: null,
            mcpInput: null,
            skillName: null,
            prompt: "git commit",
        },
        mf,
    );
    assert.equal(d.action, "allow");
    fs.unlinkSync(receiptPath("loaded", key, "git-commit-practices"));
    fs.unlinkSync(mf);
});

// ── decide: skill-load records ───────────────────────────────────────────────

test("decide → record(loaded) on PostToolUse(Skill) for a tracked skill", () => {
    const mf = tempManifest(DECIDE_FIXTURE);
    const d = decide(
        {
            event: "PostToolUse",
            agentKey: `t-${Date.now()}`,
            toolName: "Skill",
            command: null,
            mcpTool: null,
            mcpInput: null,
            skillName: "git-commit-practices",
            prompt: null,
        },
        mf,
    );
    assert.equal(d.action, "record");
    assert.equal(d.kind, "loaded");
    assert.equal(d.skill, "git-commit-practices");
    fs.unlinkSync(mf);
});

test("decide → record(loaded) on PostToolUse(read_file) for a tracked skill", () => {
    const mf = tempManifest(DECIDE_FIXTURE);
    const d = decide(
        {
            event: "PostToolUse",
            agentKey: `t-${Date.now()}`,
            toolName: "read_file",
            command: null,
            mcpTool: null,
            mcpInput: null,
            skillName: "querying-and-updating-notion",
            prompt: null,
        },
        mf,
    );
    assert.equal(d.action, "record");
    assert.equal(d.kind, "loaded");
    assert.equal(d.skill, "querying-and-updating-notion");
    fs.unlinkSync(mf);
});

test("decide → allow on PostToolUse(Skill) for an untracked skill", () => {
    const mf = tempManifest(DECIDE_FIXTURE);
    const d = decide(
        {
            event: "PostToolUse",
            agentKey: `t-${Date.now()}`,
            toolName: "Skill",
            command: null,
            mcpTool: null,
            mcpInput: null,
            skillName: "eli5",
            prompt: null,
        },
        mf,
    );
    assert.equal(d.action, "allow");
    fs.unlinkSync(mf);
});

test("decide → record(loaded) on UserPromptExpansion for /skill of a tracked skill", () => {
    const mf = tempManifest(DECIDE_FIXTURE);
    const d = decide(
        {
            event: "UserPromptExpansion",
            agentKey: `t-${Date.now()}`,
            toolName: null,
            command: null,
            mcpTool: null,
            mcpInput: null,
            skillName: "git-commit-practices",
            prompt: null,
        },
        mf,
    );
    assert.equal(d.action, "record");
    assert.equal(d.kind, "loaded");
    assert.equal(d.skill, "git-commit-practices");
    fs.unlinkSync(mf);
});

test("decide → allow when manifest is empty", () => {
    const mf = tempManifest({ version: 1, gates: [] });
    const d = decide(
        {
            event: "PreToolUse",
            agentKey: "k",
            toolName: "Bash",
            command: "git commit",
            mcpTool: null,
            mcpInput: null,
            skillName: null,
            prompt: null,
        },
        mf,
    );
    assert.equal(d.action, "allow");
    fs.unlinkSync(mf);
});
