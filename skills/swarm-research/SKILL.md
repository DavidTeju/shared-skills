---
name: swarm-research
description: |
  Two-phase research pattern: (1) quiz user to build structured selection criteria,
  (2) dispatch parallel agents across multiple models with intentionally varied context
  levels, then compile/rank/filter into a single report. Use when: (1) user asks to
  "find me a..." or "help me choose..." with multiple viable options, (2) group decisions
  with multiple constraints, (3) any scenario where breadth of search + structured
  evaluation both matter — travel planning, restaurant selection, apartment hunting,
  tech stack decisions, gear purchasing, event venue selection. Key insight: some agents
  get full criteria (targeted search) while others get minimal context (wider net,
  avoids confirmation bias). Different models surface different results.
author: Claude Code
---

# Swarm Research

A two-phase pattern for decision research that combines structured criteria elicitation
with multi-agent parallel search, then converges into a ranked, filtered report.

## Problem

When users ask for help choosing something (a backpacking spot, a restaurant, an apartment,
a tech stack), they typically under-specify what they actually need. And a single search
agent — no matter how good — has blind spots shaped by its initial framing.

The result: generic recommendations that miss non-obvious constraints, or narrowly-targeted
results that miss great options outside the search frame.

## Context / Trigger Conditions

Use this pattern when ALL of these are true:

- Multiple viable options exist (not a single right answer)
- Multiple criteria matter (not just "the best one")
- The user hasn't fully articulated their constraints
- Breadth of search adds value (different sources/angles find different things)

Common triggers:

- "Find me a backpacking spot / restaurant / apartment / gift / venue"
- "Help me choose between..." (but they haven't defined "choose by what")
- Group decisions with diverse preferences
- Any "research and recommend" task

## Solution

### Phase 1: Criteria Elicitation

**Don't start researching. Start quizzing.**

The goal is to extract a structured criteria document BEFORE any search happens. This is
the single biggest quality lever — it turns vague preferences into a scoring rubric.

**How to quiz:**

1. Ask rapid-fire questions in logical clusters (logistics, preferences, constraints, dealbreakers)
2. Use the `ask_user` tool with multiple-choice options where possible (faster for the user)
3. Probe for NON-OBVIOUS constraints — these are the ones that matter most:
   - Safety requirements that the user assumes are obvious
   - Group dynamics (not just the requester's preferences)
   - Hard dealbreakers vs. nice-to-haves (users often conflate these)
   - Practical filters (timing, budget, accessibility, logistics)
4. Reflect the criteria back as a structured document for user confirmation
5. Ask "anything to add, drop, or adjust?" before proceeding

**Criteria document structure:**

```markdown
## Must-Haves (Non-Negotiable)

- [Hard requirements that eliminate options if not met]

## Strong Preferences

- [Things that significantly improve the experience but aren't dealbreakers]

## Practical Filters

- [Logistics, timing, budget, accessibility constraints]

## Special Considerations

- [Context-specific factors — group dynamics, safety, etc.]
```

**Key principle:** The criteria doc becomes the scoring rubric for Phase 2. Time invested
here pays off 10x in research quality.

### Phase 2: Divergent Multi-Agent Search

Dispatch 4-6 agents in parallel using the `task` tool with `mode: "background"`. The
critical technique is **intentional context variation:**

**Full-context agents (2-3):**

- Get the COMPLETE criteria document
- Use different models (e.g., opus-fast + codex + gemini)
- Produce targeted, criteria-matched results
- More likely to find the "right" answer

**Minimal-context agents (2-3):**

- Get only the basic ask (e.g., "find backpacking spots near Seattle, 4 people, 2 nights")
- NO criteria, NO constraints, NO special considerations
- Use different models from the full-context agents
- Cast a wider net — find options the targeted agents miss
- Surface things the user didn't know to ask for

**Why this works:**

- Full-context agents do confirmation search (find what matches)
- Minimal-context agents do exploration search (find what exists)
- Different models have genuinely different knowledge bases and search instincts
- The overlap between agents validates strong options (Shi Shi Beach was found by 4/5 agents)
- The non-overlap surfaces hidden gems or eliminates blind spots

**Agent prompt template (full context):**

```
You are researching [DOMAIN] for [USER CONTEXT].
Here are the COMPLETE selection criteria: [FULL CRITERIA DOC]

YOUR TASK:
1. Use web_search extensively to find 4-6 specific options in [SCOPE]
2. Use web_fetch to pull details from [RELEVANT SOURCES]
3. If you get 403 errors, DON'T STOP — try alternative URLs, different queries
4. For EACH option, provide: [STRUCTURED FIELDS]
5. [DOMAIN-SPECIFIC INSTRUCTIONS]

Return a structured report. Real links, real data.
```

**Agent prompt template (minimal context):**

```
Find [THING] for [BASIC CONTEXT]. [SIMPLE CONSTRAINTS].

Use web_search and web_fetch to research real options. If you hit 403 errors,
try alternative URLs. Find 4-6 options with: [BASIC FIELDS]

Return a structured report.
```

**Model selection guidance:**

- Use 3+ different models from different providers for maximum divergence
- Premium models (opus/codex/gemini pro) for full-context agents (better criteria matching)
- Faster models work fine for minimal-context agents (breadth over depth)
- If you have access to Playwright, mention it as a fallback for blocked sites

### Phase 3: Convergent Compilation

Once all agents return:

1. **Aggregate:** Collect all unique options across all agents
2. **Note consensus:** Options found by multiple agents independently are strong signals
3. **Score against criteria:** Use the Phase 1 criteria doc as a rubric
   - Must-haves are pass/fail filters (eliminate if not met)
   - Strong preferences are weighted scores
   - Practical filters are additional pass/fail
   - Special considerations are risk flags
4. **Rank:** Order by criteria fit, noting where agents agreed/disagreed
5. **Eliminate:** Cut 2-4 options that don't meet must-haves or score poorly
6. **Report:** Produce a clean, readable report with:
   - Ranked options with details and links
   - Discarded options table (name, why cut, link) — still valuable for future reference
   - Clear recommendation with reasoning
   - Action items / next steps

## Example Applications

| Domain          | Phase 1 Quiz Clusters                                            | Full-Context Focus                                         | Minimal-Context Focus           |
| --------------- | ---------------------------------------------------------------- | ---------------------------------------------------------- | ------------------------------- |
| **Backpacking** | Group fitness, format, safety, scenery prefs, gear status        | Match trail to specific constraints (fire, tides, terrain) | "Best backpacking near [city]"  |
| **Restaurant**  | Group size, dietary restrictions, vibe, budget, occasion         | Match cuisine + ambiance + dietary needs                   | "Best restaurants in [area]"    |
| **Apartment**   | Commute, budget, lifestyle, dealbreakers, neighborhood vibe      | Match specific neighborhood + amenity needs                | "Apartments in [city] under $X" |
| **Tech Stack**  | Team skills, performance needs, scale, timeline, constraints     | Match framework to specific architecture needs             | "Best framework for [type] app" |
| **Gift**        | Recipient personality, interests, budget, occasion, relationship | Match gift to specific person profile                      | "Best gifts for [demographic]"  |

## Notes

- **Don't abandon slow agents.** In practice, the slowest agent (16 min vs 2-3 min for
  others) found the most specific, bookable results — actual Hipcamp listings with direct
  links, fire restriction warnings other agents missed, and land-ownership gotchas. Speed ≠
  quality in research. Wait for all agents before compiling, even if it feels slow.
- **Agent count:** 4-6 is the sweet spot. Fewer loses the diversity benefit. More creates
  diminishing returns and long wait times.
- **403 resilience:** Always instruct agents not to stop on 403 errors. Web research agents
  will hit blocked sites frequently — they need to try alternative URLs, reformulate queries,
  or use browser tools.
- **Playwright:** If available, mention it in agent prompts as a fallback for sites that
  block simple fetches. Note that multiple agents can't share a single Playwright session
  simultaneously.
- **Consensus scoring:** If 4/5 agents independently find the same option, that's a
  strong signal regardless of how it scores on paper criteria. Note these in the report.
- **The "minimal context surprise":** The most valuable finds often come from minimal-context
  agents. They search without preconceptions and sometimes surface category-breaking options
  (e.g., a river valley option nobody asked for that turns out to be the safest choice).

## Verification

The pattern is working when:

- Full-context agents return options that closely match criteria
- Minimal-context agents return at least 1-2 options the full-context agents missed
- The final report has a clear #1 recommendation with reasoning
- Discarded options are documented (not lost)
- The user can make a decision from the report without further research
