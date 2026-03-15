---
name: so
description: |
  Stack Overflow terminal interface via StackExchange API. Use when: (1) need to look up
  a programming question on Stack Overflow, (2) searching StackExchange sites (unix, superuser,
  serverfault), (3) fetching SO answers programmatically from a script or agent context.
  Aliased to always use `-e stackexchange` (Google/DuckDuckGo backends are blocked).
user-invocable: false
---

# so — Stack Overflow CLI

Terminal interface for searching and browsing Stack Overflow and other StackExchange sites.

## Quick Start

```bash
brew install so
```

**Alias (already configured):** `so` is aliased to `so -e stackexchange` in `~/scripts/aliases.zsh`.
This is critical — the default Google search engine is blocked, and DuckDuckGo is unreliable.

## Core Workflows

### Quick answer lookup

```bash
so --lucky "python reverse list"
```

Returns the top-voted answer from the most relevant question, rendered with syntax highlighting.
Output is plain text with ANSI color codes — not JSON. No machine-readable output mode exists.

# WARNING: --lucky still requires a TTY (uses Crossterm for rendering).
# In non-TTY contexts (scripts, agents), fake a TTY:
script -q /dev/null so --lucky "python reverse list" 2>&1

### Search other StackExchange sites

```bash
so -s unix "systemd service restart"
so -s superuser "windows dual boot grub"
so -s serverfault "nginx reverse proxy websocket"
```

Common site codes: `stackoverflow` (default), `unix`, `superuser`, `serverfault`,
`askubuntu`, `dba`, `math`, `stats`, `tex`. Full list: `so --list-sites`.

### Limit results

```bash
so -l 5 "rust lifetime error"
```

Default is 20 questions. Use `-l` to reduce when you want faster results.

### Agent/script usage (non-TTY)

`so` is a TUI app — it requires a terminal. To use programmatically:

```bash
# Fake a TTY with script, pipe output
ANSWER=$(script -q /dev/null so -e stackexchange --lucky "git rebase autosquash" 2>&1)
echo "$ANSWER"
```

Output contains ANSI escape codes. To strip them:

```bash
script -q /dev/null so -e stackexchange --lucky "query here" 2>&1 | sed $'s/\x1b\[[0-9;]*[a-zA-Z]//g'
```

# WARNING: The first few lines contain spinner characters (⢀⠀, ⡀⠀, etc.) from the loading
# animation. These are harmless but appear in piped output.

## Error Recovery

| Error | Type | Action |
|-------|------|--------|
| "Sorry, couldn't find any answers" | Query issue | Broaden search terms, try different phrasing |
| "DuckDuckGo blocked this request" | Permanent | Don't use `-e duckduckgo` — use stackexchange |
| "Crossterm error: Device not configured" | Environment | Not in a TTY — use `script -q /dev/null` wrapper |
| "StackOverflow captcha check triggered" | Transient | Only happens with `-e stackexchange` direct SO search, rare. Wait and retry |
| Rate limiting (300 req/day) | Transient | Register an API key: `so --set-api-key <key>` |

## Do NOT Use This For

- **Getting JSON/structured data** — `so` only outputs rendered text. If you need structured SO data, use the StackExchange API directly.
- **Posting questions or answers** — read-only tool.
- **Authenticated actions** — no login support (voting, commenting, etc.)

## Gotchas

- **Google engine is dead.** `-e google` (the default without the alias) returns "No results found" on every query. Google blocks the scraping. This is why the alias forces `-e stackexchange`.
- **DuckDuckGo is flaky.** Works from real browsers but blocks programmatic requests. Don't rely on it.
- **No machine-readable output.** Everything is ANSI-rendered text. For agent use, you must strip escape codes.
- **TTY required.** Even `--lucky` (non-interactive mode) uses Crossterm and fails without a TTY. Always wrap with `script -q /dev/null` in automated contexts.
- **Python 3.14 compatibility** is untested (only tested through 3.13). The Rust binary from Homebrew doesn't have this issue.
