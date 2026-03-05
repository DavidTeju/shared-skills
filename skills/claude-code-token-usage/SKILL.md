---
name: claude-code-token-usage
description: |
  Calculate project-specific token usage and costs from Claude Code session data.
  Use when: (1) user asks "how many tokens have I used?", (2) user wants to see
  project costs, (3) analyzing Claude Code usage patterns, (4) comparing usage
  across projects. Covers parsing ~/.claude session files, extracting token
  counts, and calculating estimated costs with prompt caching.
author: Claude Code---

# Claude Code Token Usage Analysis

## Problem
Users want to know how many tokens (and estimated cost) they've spent on a specific
project using Claude Code. This data isn't surfaced in the CLI directly but is stored
in session files.

## Context / Trigger Conditions
- User asks about token usage, costs, or spending
- User wants project-specific (not global) usage data
- User wants to understand the impact of prompt caching
- Analyzing usage patterns across sessions

## Data Locations

### Global Stats
`~/.claude/stats-cache.json` - Contains aggregated usage across all projects

### Project-Specific Data
`~/.claude/projects/{project-path}/*.jsonl` - Session transcripts with per-message token usage

The project path is the absolute path with slashes replaced by dashes:
- `/Users/name/projects/myapp` → `-Users-name-projects-myapp`

## Solution

### Quick Script to Calculate Project Token Usage

```javascript
// Run with: node -e '<script>'
const fs = require("fs");
const path = require("path");

// Replace with actual project path
const projectSlug = "-Users-username-projects-project-name";
const dir = process.env.HOME + "/.claude/projects/" + projectSlug;
const files = fs.readdirSync(dir).filter(f => f.endsWith(".jsonl"));

let inputTokens = 0;
let outputTokens = 0;
let cacheReadTokens = 0;
let cacheCreationTokens = 0;
let messages = 0;

files.forEach(file => {
  const content = fs.readFileSync(path.join(dir, file), "utf-8");
  content.split("\n").filter(Boolean).forEach(line => {
    try {
      const obj = JSON.parse(line);
      if (obj.type === "assistant" && obj.message?.usage) {
        const u = obj.message.usage;
        inputTokens += u.input_tokens || 0;
        outputTokens += u.output_tokens || 0;
        cacheReadTokens += u.cache_read_input_tokens || 0;
        cacheCreationTokens += u.cache_creation_input_tokens || 0;
        messages++;
      }
    } catch(e) {}
  });
});

console.log({ inputTokens, outputTokens, cacheReadTokens, cacheCreationTokens, messages, sessions: files.length });
```

### Cost Calculation (Claude Opus 4.5 Pricing)

```javascript
// Rates per 1M tokens (as of early 2026 - 67% reduction from old Opus pricing)
const INPUT_RATE = 5;         // $5/M
const OUTPUT_RATE = 25;       // $25/M
const CACHE_READ_RATE = 0.50; // $0.50/M (90% discount from input)
const CACHE_CREATION_RATE = 6.25; // $6.25/M

const inputCost = (inputTokens / 1_000_000) * INPUT_RATE;
const outputCost = (outputTokens / 1_000_000) * OUTPUT_RATE;
const cacheReadCost = (cacheReadTokens / 1_000_000) * CACHE_READ_RATE;
const cacheCreationCost = (cacheCreationTokens / 1_000_000) * CACHE_CREATION_RATE;
const totalCost = inputCost + outputCost + cacheReadCost + cacheCreationCost;

// Calculate savings from caching
const withoutCacheCost = ((cacheReadTokens + cacheCreationTokens + inputTokens) / 1_000_000) * INPUT_RATE + outputCost;
const cacheSavings = withoutCacheCost - totalCost;
```

## JSONL Message Structure

Each session file contains JSON lines with this structure for assistant messages:
```json
{
  "type": "assistant",
  "message": {
    "usage": {
      "input_tokens": 1234,
      "output_tokens": 567,
      "cache_read_input_tokens": 89000,
      "cache_creation_input_tokens": 45000
    }
  }
}
```

## Verification
- List projects: `ls ~/.claude/projects/`
- Count sessions: `ls ~/.claude/projects/{project-path}/*.jsonl | wc -l`
- Check global stats: `cat ~/.claude/stats-cache.json | jq .modelUsage`

## Example Output
```
=== Token Usage for Project ===

Direct tokens:
  Input:          615,337 ($3.08)
  Output:         37,937 ($0.95)

Cached tokens:
  Cache reads:    1,268,611,003 ($634.31)
  Cache creates:  76,097,253 ($475.61)

Total: 1.35 billion tokens, ~$1,113.94
Cache saved: $5,614 (83.4% savings)
```

## Notes
- Token counts are cumulative across all sessions for the project
- Cache tokens dominate usage in long-running projects (codebase context is cached)
- Pricing varies by model (Haiku is much cheaper than Opus)
- The `stats-cache.json` has global data but not per-project breakdowns
- Session files also contain full conversation transcripts for debugging/analysis
