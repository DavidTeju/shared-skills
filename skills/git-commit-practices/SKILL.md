---
name: git-commit-practices
description: |
  Git commit best practices for Claude Code. Use when: (1) about to create a git commit,
  (2) user asks to commit changes, (3) bundling multiple changes together. Covers atomic
  commits, meaningful messages, what not to commit, and ensuring commit messages reflect
  all changes in the diff.
author: David Tejuosho
user-invocable: true
---

# Git Commit Best Practices

## Problem

Claude tends to make poor commits: bundling unrelated changes, writing vague messages
that reference external context, and committing working documents that shouldn't be
version controlled.

## Context / Trigger Conditions

Apply these practices whenever:
- Creating a git commit
- User asks to "commit this" or "make a commit"
- Multiple files have been modified in a session
- About to stage files with `git add`

## Rules

### 1. Atomic Commits

**One logical change per commit.** Group related files if they're part of the same
feature or fix, but don't bundle unrelated changes.

**This often means making MULTIPLE commits.** Before staging anything, analyze all
modified files and determine how many logical changes exist. If there are 3 unrelated
changes, plan for 3 separate commits.

**NEVER bundle for "efficiency".** Making many small commits is NOT inefficient - it's
correct. Each commit should be independently revertable and understandable. The extra
time spent making atomic commits is always worth it.

**What counts as ONE logical change:**
- A single service/module and its tests
- A single component and its styles
- A single tRPC router
- Schema changes for ONE model/feature
- One bug fix (even if it touches multiple files)
- One refactor with a clear purpose

**What is NOT one logical change (must be separate commits):**
- Multiple epics or features (even if implemented together)
- A service + an unrelated UI component
- Analytics router + Insights router (separate domains)
- Detector A + Detector B (separate concerns)
- "All the Phase 4 stuff" - NEVER

Bad:
```
git add . && git commit -m "Fix bug and update docs and add feature"
# Also bad:
git commit -m "feat(insights): Add analytics, detectors, UI, and Q&A (Epics 2, 3, 7, 12)"
```

Good:
```
git add src/auth.ts src/middleware.ts && git commit -m "Fix session expiry bug"
git add README.md && git commit -m "Document new auth flow"
# For feature work:
git commit -m "feat(insights): Add spending-calculator service with tests"
git commit -m "feat(insights): Add trend-calculator service with tests"
git commit -m "feat(insights): Add spending-change detector"
```

### 2. Never Commit Working Documents

Do NOT commit:
- Code review notes (CODE_REVIEW.md, REVIEW.md)
- Work in progress docs (WIP.md, TODO.md, NOTES.md)
- Temporary analysis files
- Personal notes or scratch files

These stay local or in `.gitignore`.

### 3. Self-Explanatory Messages

Commit messages must make sense to someone who:
- Doesn't have access to your chat history
- Doesn't have your issue tracker
- Is reading `git log` months later

**Avoid project jargon and internal labels.** Terms like "Phase 1", "Chunk 2",
"Epic 7", "Sprint 3", or "Milestone 2" are meaningless in `git log`. Describe
what the code actually does, not which planning bucket it belongs to.

Bad:
```
Fix code review issues #2, #4, #21
Add Phase 1 chunk roadmap
Complete Chunk 2 implementation
```

Good:
```
Wrap suggestion approval in Prisma transaction

Prevents race conditions when approving suggestions. All response
changes and status updates now happen atomically.
```

### 4. Message Must Reflect ALL Changes in Diff

Before committing, **read the actual diff** (`git diff --staged`). The commit message
must account for everything being committed.

If the diff includes:
- A bug fix
- Schema changes
- Documentation updates
- New models

Then the commit message must mention ALL of these, not just the primary change.

Example of a complete message:
```
Wrap suggestion approval in Prisma transaction

Prevents race conditions when approving suggestions.
All response changes and status updates now happen atomically.

Also updates deploy/README.md with:
- Request logging documentation
- Email subject configuration
- GeoIP blocking setup
```

### 5. Structure

```
<type>: <short summary in imperative mood>

<body explaining WHY, not just what>

<footer with co-author if applicable>
```

The body should explain:
- Why this change was needed
- What problem it solves
- Any non-obvious implications

## Verification

Before committing, verify:
- [ ] `git diff --staged` shows only related changes
- [ ] No working documents are staged
- [ ] Commit message describes ALL changes in the diff
- [ ] Message is self-explanatory without external context

## Anti-Patterns

1. **"Fix stuff"** - Vague, useless message
2. **"WIP"** - Don't commit work in progress
3. **"Address review comments"** - Says nothing about what changed
4. **"Issue #123"** - Reference is fine, but explain the change too
5. **Bundling unrelated fixes** - Harder to revert, bisect, or review
6. **"Efficiency" bundling** - Combining multiple features/services/epics to "save time"
7. **Epic commits** - Listing multiple epics in one commit message (e.g., "Epics 2, 3, 7")
8. **Mega-features** - "Add entire Phase 4" or "Complete insights feature"
9. **Project jargon** - "Phase 1", "Chunk 2", "Epic 7", "Sprint 3" — describe what it does, not which planning bucket it's in

### The Efficiency Trap

It may FEEL efficient to bundle changes, but it creates:
- Commits that can't be cleanly reverted
- Git blame that's useless for tracking down issues
- PRs that are impossible to review
- History that's hard to bisect

**Rule of thumb:** If you're listing multiple things in the commit message with "and"
or commas, you probably need multiple commits.

## Notes

- When changes ARE related (same feature/fix), one commit is fine
- Use `git add -p` to stage partial files if needed
- If you realize a commit was wrong, offer to amend or reset
