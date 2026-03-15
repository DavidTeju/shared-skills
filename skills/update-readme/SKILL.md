---
name: update-readme
description: |
  Update README and documentation files to match the current state of the codebase.
  Use when: (1) user asks to "update the readme", "sync docs", or "docs are stale",
  (2) after significant refactors or feature additions, (3) user asks "is the README
  accurate?", (4) CLAUDE.md instructions say to check docs after changes. Finds what
  changed since docs were last touched, then makes targeted correctness and completeness
  fixes. Does NOT rewrite for style — preserves the author's voice and structure.
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Agent
---

# update-readme

Update project documentation to match the current state of the code. Prioritize
**correctness** (wrong info is worse than missing info), then **completeness** (only
add what's clearly needed). Preserve the author's structure, tone, and style.

## Inputs

The user may provide:
- A specific file path (e.g., `README.md`, `docs/setup.md`)
- A directory to scan for docs
- Nothing — in which case, discover docs automatically

## Process

### Phase 1: Discover Documentation

Find all documentation files in the project:

```
Glob for: README.md, **/README.md, docs/**/*.md, CONTRIBUTING.md, CHANGELOG.md,
          SETUP.md, ARCHITECTURE.md, *.md in project root
```

Exclude: `node_modules/`, `.git/`, `workspace/`, `temp/`, vendor dirs.

If the user specified a file, skip discovery and use that file.

Present the list to the user and ask which files to update (unless only one exists
or the user already specified).

### Phase 2: Determine What Changed

For each doc file, find the last commit that touched it:

```bash
git log -1 --format="%H %ai" -- <doc-file>
```

Then get all changes since that commit:

```bash
# Summary of what changed since docs were last updated
git diff --stat <last-doc-commit>..HEAD -- . ':!<doc-file>'

# Detailed diff for understanding changes (use Agent for large diffs)
git log --oneline <last-doc-commit>..HEAD
```

If the doc has **never been committed**, compare against the full current state.

### Phase 3: Read and Analyze

Read each documentation file in full. For each section, classify it:

1. **Correct** — matches current code, no action needed
2. **Incorrect** — contradicts current code (HIGHEST PRIORITY to fix)
3. **Stale** — references removed/renamed things
4. **Incomplete** — missing significant new functionality that a reader would expect
5. **Aspirational** — describes planned features not yet implemented (flag but don't remove
   unless the user confirms)

To verify claims in the docs, read the actual source files they reference. Don't assume
docs are correct — verify against code.

Key things to check:
- **Installation/setup steps** — do the commands still work? Are dependencies accurate?
- **API documentation** — do endpoints, parameters, return types match the code?
- **Configuration** — are env vars, config files, and their defaults accurate?
- **File/directory references** — do referenced paths still exist?
- **Code examples** — do they use current function signatures and APIs?
- **Feature lists** — are listed features still present? Are major new features missing?
- **Architecture descriptions** — does the described structure match reality?

### Phase 4: Make Targeted Edits

Apply fixes using the Edit tool. Rules:

- **Fix incorrect information immediately** — wrong docs are actively harmful
- **Remove references to deleted things** — stale paths, removed features, old APIs
- **Add missing info only when clearly needed** — a new major feature that the README
  claims to document but doesn't mention yet
- **Do NOT:**
  - Rewrite sections for "better" prose or formatting
  - Add sections that weren't there before (unless critical)
  - Change the author's tone, voice, or conventions
  - Add emoji, badges, or decorative elements
  - Restructure the document's organization
  - Add type annotations, JSDoc, or inline docs (that's a different task)
  - Over-document — match the existing level of detail

### Phase 5: Summary

After edits, provide a brief summary:
- What was changed and why
- Anything flagged as potentially aspirational/planned
- Any sections that seem incomplete but were left alone (explain why)

## Edge Cases

- **Monorepo with multiple READMEs:** Process each independently. Changes in `packages/foo`
  only affect `packages/foo/README.md`, not the root README (unless root references foo).
- **No git history:** Compare docs against current code state. Note that you can't determine
  staleness without history.
- **Massive changelog:** Use an Agent to analyze the diff and summarize relevant changes
  rather than reading the entire diff inline.
- **Doc references external systems:** Flag but don't verify (you can't check if a URL is
  live or if a dashboard still exists). Note it in the summary.

## Anti-Patterns

1. **Full rewrites** — You're updating, not rewriting. Touch only what's wrong.
2. **Adding "helpful" context** — If the author left something terse, that was a choice.
3. **Formatting changes** — Don't normalize markdown style, heading levels, or whitespace
   unless it's broken rendering.
4. **Commit message inflation** — Don't describe trivial punctuation fixes as "major
   documentation overhaul."
5. **Trusting the docs** — The whole point is that docs drift. Verify against code.
