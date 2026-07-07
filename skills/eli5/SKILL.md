---
name: eli5
description: Use when asked to explain, describe, or write up a topic for a technically competent audience that lacks project-specific or insider context — onboarding a new teammate, an outside reviewer, external docs, or when the user says "explain to someone unfamiliar", "don't assume inside knowledge", or "assume no context".
---

# Explaining Without Assumed Context

## Overview

You are steeped in this project's jargon, files, and history. Your reader is a sharp engineer who opened the repo five minutes ago.

**Core principle:** Assume full general-technical fluency (git, SQL, HTTP, TypeScript) and ZERO project-specific knowledge. Every project-local name must be introduced before it is used.

## When to Use

- The user says "explain to someone unfamiliar", "don't assume inside knowledge", "assume no context", or "for a newcomer".
- Writing onboarding docs, a PR description for an outside reviewer, or a design explainer.
- You catch yourself about to name an internal file/table/component as if it were common knowledge.

## The Technique

1. **Start one level up.** Before the specific subject, spend 2–4 sentences on the system it lives in and the problem it solves. A part makes no sense without the whole.
2. **Define every project-local term on first use** — acronyms, file names, scripts, tables, components, internal nouns. Anchor each to a general concept they already know: *"X is a git worktree — a second working directory checked out from the same repo on a different branch."*
3. **Calibrate the level.** They know general tech cold — never re-explain git, SQL, or HTTP. Only explain what is specific to THIS project.
4. **Explain WHY, not just what.** State what a thing is for and what breaks without it.
5. **Use real names and paths**, not `foo`/`bar` placeholders. Concreteness from the actual project beats abstraction.
6. **Layer it:** context → the thing itself → the decision or implication.

## Quick Reference — pre-send checklist

- [ ] Would this land for someone who opened the repo 5 minutes ago?
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
| Saying *what* without *why* | Add the purpose and the failure it prevents |
| Abstract `foo`/`bar` placeholders | Use the project's real names and paths |
