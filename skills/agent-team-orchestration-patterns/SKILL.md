---
name: agent-team-orchestration-patterns
description: |
  Patterns and anti-patterns for orchestrating multi-agent teams on complex research
  and planning tasks. Use when: (1) dispatching 3+ agents for a complex task like
  calendar restructuring, trip planning, or multi-source research, (2) user explicitly
  asks for agent teams, (3) task requires gathering data from multiple sources and
  synthesizing into a plan. Covers: agent role design, iteration loops, scratchpad
  usage, re-dispatching idle agents, critique pass structure, cross-referencing between
  agents, and handling user corrections mid-task.
author: Claude Code
user-invocable: false
---

# Agent Team Orchestration Patterns

## Problem
Complex planning tasks (calendar restructuring, trip planning, research synthesis)
require multiple agents gathering data in parallel, but naive orchestration leads to:
- Agents working with stale or incorrect assumptions
- Single-pass research that misses critical details
- New agents spawned instead of re-using idle ones
- Findings not cross-referenced between agents
- User corrections not propagated to all agents

## Context / Trigger Conditions
- Task requires data from 3+ sources (calendar, Notion, web, transit schedules, etc.)
- User explicitly asks for agent teams or sub-agents
- Task involves research → plan → critique → execute pipeline
- Multiple agents need to work on related sub-problems

## Solution

### 1. Agent Role Design
Assign agents narrow, specific roles with clear outputs:

| Role | Purpose | Output |
|------|---------|--------|
| Data Gatherer | Pull raw data from one source | Structured data file |
| Researcher | Search + synthesize across sources | Research report with dates/sources |
| Time Validator | Cross-check estimates against historical data | Validated estimates |
| Commute/Transit | Look up specific routes + times | Time tables with exact times |
| Critic | Review plan for errors, gaps, unrealistic estimates | Prioritized issue list |

**Key rule:** Every agent should be told to flag data freshness. Include in every
agent's instructions: "Check dates on all sources. Flag anything potentially stale."

**Two specialist roles worth adding to ANY complex task:**

| Role | Purpose | Why It Works |
|------|---------|--------------|
| **Data Guzzler** | Reads EVERYTHING — all files, all sources, all raw data. Finds connections between artifacts that individual agents missed. | Catches cross-cutting concerns: a deadline in Notion that affects the calendar, a preference in messages that contradicts a plan assumption. Found 30 findings in one pass that 2 critics missed. |
| **Consistency Hammerer** | Checks every number, every timestamp, every duration. Does end_time - start_time = stated duration? Any gaps? Overlaps? Claims match source data? | Catches arithmetic bugs that qualitative reviewers skip. Found 25 issues including time overlaps, stale references, and math errors in summary tables. |

**Data Guzzler deployment:** After the draft exists but before critics. Give it ALL artifacts.
**Consistency Hammerer deployment:** After critic passes, on the "final" draft. Pure arithmetic.

### Additional Agent Rules

**Agents can't use AskUserQuestion.** Team agents don't have this tool. All user questions must be relayed through the team lead.

**Agent that rejects shutdown:** If an agent argues it should keep working, evaluate its claim honestly. If it has context and the replacement agent would need to re-learn everything, let it finish. But if its original instructions were wrong (e.g., told to consolidate when you need granular), replacing is better than trying to redirect mid-stream.

### 2. The Scratchpad is a Living Document
The scratchpad should be a running log, NOT a polished document.

**Structure it with:**
- **Rules** — discovered constraints, logged as they're learned
- **Confirmed Facts** — things the user stated directly (these override research)
- **Open Questions** — unresolved items, with who's investigating
- **Decision Log** — dated entries for each decision and why
- **Things to Verify** — items that need cross-referencing

**Anti-pattern:** Writing the scratchpad once as a final summary. It should be
updated continuously — before and after every major decision.

### 3. Iteration Loop (Not a Pipeline)
Don't run: research → plan → critique → present.

Instead run:
```
research → draft plan → critique → FIX ISSUES → second critique →
check critique's work → present
```

**Minimum 2 critique passes.** The second critic should:
- Verify fixes from the first critique were actually applied
- Check the first critic's math/assumptions
- Catch issues the first critic missed
- Trace minute-by-minute timelines for scheduling tasks

### 4. Re-dispatch Idle Agents (Don't Spawn New Ones)
When new information comes in after initial research:
- **DO:** Send a follow-up message to the relevant idle agent
- **DON'T:** Spawn a new agent for the same domain

Idle agents retain their full context. A follow-up message like "Femi says Planet
Fitness is on Rainier Ave, not Capitol Hill. Update your transit estimates." is
far more efficient than spawning a fresh agent with no context.

### 5. Cross-Reference Between Agents
When Agent A produces findings that affect Agent B's work:
- Relay the key findings to Agent B immediately
- Don't wait until all agents finish to discover conflicts
- Example: if the commute researcher discovers the office is in Redmond,
  the life researcher needs to know immediately (to stop claiming SLU)

### 6. User Corrections Are Facts
When the user corrects something:
1. Update the scratchpad immediately
2. Relay the correction to ALL affected agents
3. DO NOT mark it as "unclear" or "needs verification" — user statements are ground truth

### 7. Sanity-Check Nonsensical Data
If data doesn't make sense in context, investigate before accepting:
- A work standup at 11 PM → timezone issue, not a real meeting time
- A 5-minute block for house cleaning → unrealistic, flag it
- An office location that doesn't match the commute pattern → stale data

**Rule: If it doesn't make sense, it's probably wrong. Investigate.**

### 8. Agent Communication Template
When dispatching an agent, include:
```
1. Specific task with clear deliverable
2. What sources to check (and what dates to verify)
3. Known facts from the user (these are NOT debatable)
4. What to flag if uncertain (don't mark as "unclear" — ask)
5. Where to save output
6. Who to message when done
```

## Verification
After the team produces a plan:
- [ ] Every user-stated fact is reflected correctly
- [ ] All data has been cross-referenced against at least 2 sources
- [ ] Timezone conversions are applied (if applicable)
- [ ] Transit times are verified with exact addresses
- [ ] At least 2 critique passes were completed
- [ ] The second critic checked the first critic's work
- [ ] The scratchpad has dated entries, rules, and open questions
- [ ] No agent output is blindly trusted — spot-check key claims

## Anti-Patterns (All Observed in Real Sessions)

| Anti-Pattern | What Happened | What Should Have Happened |
|---|---|---|
| **Spawning over re-using** | New "gap-filler" agent created when commute-researcher was idle | Send commute-researcher a follow-up message |
| **Single critique pass** | User asked for 2 passes, got 1 | Always do minimum 2 passes |
| **Scratchpad as final doc** | Scratchpad was a polished summary, not a working log | Date entries, track open questions, log rules in real-time |
| **Trusting stale data** | Life researcher reported "SLU office" from outdated USER.md | Cross-reference against current calendar patterns |
| **Not propagating corrections** | User said "542 to U-District for climbing" — commute agent marked it "unclear" | User statements are facts. Relay to all agents. |
| **Accepting nonsensical times** | Work meetings at 11 PM accepted as real | Investigate: 11 PM standup → timezone issue |
| **Doing work agents should do** | Team lead looked up 542 bus schedule himself | Send the commute agent to do it |
| **Shutdown + redirect race** | Sent shutdown, then immediately messaged "actually, keep going." Agent accepted old shutdown before reading the redirect. | Commit to one path: either shut down OR redirect. Never both. |
| **Two agents, one job** | Two implementers both tried to create calendar events simultaneously, risking duplicates. | One agent per artifact. Fully shut down the first before starting the second. |
| **Ambiguous output format** | Said "create events" — agent consolidated 15-min blocks into 2-hour mega-blocks. | Be explicit about what NOT to do: "EVERY row = one event. Do NOT merge or consolidate." |
| **Agents claiming unverified facts** | Commute agent said "542 stops at Redmond Tech Station" — wrong. Also "mostly downhill" — wrong (it's uphill). | Verify geography, transit stops, and directional claims against web/map data. |
| **Firing agents on completion** | Shut down agents immediately after their task finished, losing their context for follow-ups. | Keep idle agents alive unless truly unneeded. They can be repurposed cheaply. |

## Notes
- The user said "I have infinite tokens. Use them." When in doubt, do more research,
  not less. Run another critique pass. Send another agent to verify.
- Agent teams are most valuable when agents ITERATE, not just run once.
- The team lead's job is orchestration, not execution. Resist the urge to do the
  research yourself.
