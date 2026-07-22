---
name: eli5
description: Use when asked to explain, describe, or write up a topic for a technically competent audience that lacks project-specific or insider context — onboarding a new teammate, an outside reviewer, external docs, or when the user says "explain to someone unfamiliar", "don't assume inside knowledge", or "assume no context".
---

# Explaining Without Assumed Context

## Overview

You are steeped in this project's jargon, files, and history. Your reader is a sharp engineer who opened the repo five minutes ago.

**Core principle:** Assume full general-technical fluency (git, SQL, HTTP, TypeScript) and ZERO project-specific knowledge. Every project-local name must be introduced before it is used.

**Three tiers of knowledge.** The single hardest calibration mistake is mislabeling a concept's tier. Sort every concept in your material into one of three buckets:

| Tier | What it is | Examples | What to do |
|---|---|---|---|
| **1 — General technical fluency** | Universal engineering knowledge any professional has | git, SQL, HTTP, JSON, REST, typed languages, threads, containers | **Assume known.** Never explain, never quiz. |
| **2 — Specialized domain knowledge** | Transferable but *non-universal* — a strong generalist engineer may or may not know it | OAuth Proof-of-Possession, OBO, app-asserted-user tokens, JWT claims, SAML, Kerberos, mTLS, CRDTs, Raft/consensus, B-tree internals, memory ordering | **Depends on the reader → quiz** (see below). Never silently assume fluency; never silently over-explain. |
| **3 — Project-local names** | This repo's files, tables, components, scripts, internal acronyms | `Directory.Packages.props`, `PlannerAppAssertedUserAccessTokenProviderFactory.cs`, "MTRS", "the shared repo" | **Always define on first use.** The reader cannot possibly know these. Never quiz. |

Tier 2 is the tier the naive skill misses — it is neither "general tech you can assume" nor "project trivia you must define." A talented engineer can be completely fluent in Tier 1 and Tier 3-adjacent reasoning yet have never touched Proof-of-Possession or OBO. Guessing wrong in *either* direction ruins the explanation: assume they know it and they're lost; explain it from scratch and you've buried the point under a lecture they didn't need.

## When to Use

- The user says "explain to someone unfamiliar", "don't assume inside knowledge", "assume no context", or "for a newcomer".
- Writing onboarding docs, a PR description for an outside reviewer, or a design explainer.
- You catch yourself about to name an internal file/table/component as if it were common knowledge.
- Your material leans on **Tier-2 specialized domain knowledge** (auth flows, distributed-systems primitives, cryptography, niche protocols) that a strong engineer might not have — quiz before you assume (see "Calibrate Tier-2").

## The Technique

1. **Start one level up.** Before the specific subject, spend 2–4 sentences on the system it lives in and the problem it solves. A part makes no sense without the whole.
2. **Define every project-local term on first use** — acronyms, file names, scripts, tables, components, internal nouns. Anchor each to a general concept they already know: *"X is a git worktree — a second working directory checked out from the same repo on a different branch."*
3. **Sort concepts into the three tiers, then calibrate.** Never re-explain Tier 1 (git, SQL, HTTP). Always define Tier 3 (project-local names). For Tier 2 (specialized domain knowledge), **don't guess — quiz the reader** (next section) and explain each concept to the depth they asked for.
4. **Explain WHY, not just what.** State what a thing is for and what breaks without it.
5. **Use real names and paths**, not `foo`/`bar` placeholders. Concreteness from the actual project beats abstraction.
6. **Layer it:** context → the thing itself → the decision or implication.

## Calibrate Tier-2 — quiz before you assume

You cannot tell from a stranger's job title whether they know Proof-of-Possession or OBO. Two equally-talented engineers need opposite documents: one wants the jargon taught from scratch, the other wants you to skip straight to the decision. So **ask**, don't guess.

**Step 1 — Detect.** After reading your material, list the Tier-2 concepts that are *load-bearing* — the ones the reader must understand for the explanation to land. Exclude Tier-1 (assume) and Tier-3 (always define). If the list is empty, skip the quiz and write normally.

**Step 2 — Quiz** (only when you can interactively ask a real person). Use the `ask_user` tool with **one grouped multi-select form**. List each load-bearing Tier-2 concept and let the reader mark how much they want on it. Offer three depth levels per concept:
   - **Know it** — use the term freely, at most a one-line parenthetical reminder.
   - **Refresher** — 1–2 sentence reminder plus a concrete analogy before using it.
   - **From scratch** — full build-up in dependency order (e.g. bearer → PoP → AT_POP → AAU, each concept built on the previous one).

   Keep it to a single form. Cap it at ~6–8 concepts; if there are more, quiz only the most load-bearing and default the rest to Refresher. Example form fields: a multi-select for "explain from scratch", a multi-select for "just a refresher", and treat everything left unchecked as "know it."

**Step 3 — Calibrate.** Write each Tier-2 concept to exactly the depth requested. This is the difference between two documents built from the *same facts*: a "from scratch" version teaches every auth concept (right for a reader weak in identity), while a "migration report" version uses them freely and spends its space on rigor and the decision (right for a reader already fluent). Same facts, different calibration — the quiz is how you pick which one to write.

**Fallback when you cannot ask** (batch job, PR description, non-interactive doc): do **not** silently pick a side. Default every Tier-2 concept to **Refresher** depth — a one-line definition plus analogy on first use — and add a short note up front listing the specialized concepts assumed, e.g. *"Assumes familiarity with OAuth bearer tokens, PoP, OBO, and AAU; each is briefly reintroduced on first use."* That way a fluent reader skims past and a weaker reader has a foothold and knows what to go read.

## Quick Reference — pre-send checklist

- [ ] Would this land for someone who opened the repo 5 minutes ago?
- [ ] Did I sort concepts into the three tiers (general / specialized-domain / project-local)?
- [ ] Did I quiz the reader on load-bearing Tier-2 concepts instead of guessing — or, if non-interactive, default them to Refresher and flag the assumptions?
- [ ] Is every acronym / file / tool / internal name defined on first use?
- [ ] Did I establish the surrounding system before the specific detail?
- [ ] Did I explain *why*, not only *what*?
- [ ] Did I avoid re-explaining general tech they already know?
- [ ] Real examples, not placeholders?

## Common Mistakes

| Mistake | Fix |
|---|---|
| Diving into the specific subject with no surrounding context | Open with the system + the problem it solves |
| Dropping an internal name (script, table, component) as if universal | Define it on first mention, tied to a known concept |
| Over-explaining general tech (condescending) | Assume fluency in git/SQL/HTTP/etc. |
| **Treating specialized domain jargon (PoP, OBO, AAU, Raft, SAML) as if it were general tech** | It's Tier 2 — quiz the reader on it; don't assume they know it |
| **Teaching every domain concept from scratch to a reader who's already fluent** | Quiz first; for "know it" concepts, use the term freely and spend the space on rigor and the decision |
| Saying *what* without *why* | Add the purpose and the failure it prevents |
| Abstract `foo`/`bar` placeholders | Use the project's real names and paths |
