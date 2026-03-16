---
name: so
description: |
  Stack Overflow terminal interface with Startpage, StackExchange API, Google, and DuckDuckGo
  backends. Use when: (1) need to look up a programming question on Stack Overflow,
  (2) searching StackExchange sites (unix, superuser, serverfault), (3) fetching SO answers
  programmatically from a script or agent context. Default engine: Startpage. Use --print
  for non-TTY/pipeable output.
user-invocable: false
---

# so — Stack Overflow CLI

Terminal interface for searching and browsing Stack Overflow and other StackExchange sites.

**Custom build** from [DavidTeju/so](https://github.com/DavidTeju/so) fork with Startpage backend and `--print` flag. Binary at `/opt/homebrew/bin/so`, backup of original Homebrew version at `/opt/homebrew/bin/so.brew-backup`.

## Quick Start

```bash
# Default engine is Startpage (Google results via privacy proxy)
so "python reverse list"

# Print to stdout without TUI (no TTY needed — best for agents/scripts)
so --print "python reverse list"
so -p "git rebase autosquash"
```

## Core Workflows

### Quick answer lookup

```bash
so --lucky "python reverse list"
```

Returns the top-voted answer from the most relevant question, rendered with syntax highlighting. Requires a TTY (uses Crossterm spinner + keypress wait).

### Print mode (agent/script usage)

```bash
so --print "python reverse list"
so -p "git rebase autosquash"
ANSWER=$(so -p "bash array syntax" 2>/dev/null)
so -p "rust lifetime" | head -20
```

`--print` / `-p` prints the top answer to stdout and exits immediately. No spinner, no keypress wait, no TUI. Fully pipeable. **Use this in non-TTY contexts** — no `script -q /dev/null` wrapper needed.

Output contains ANSI escape codes. To strip them:

```bash
so -p "query here" 2>/dev/null | sed $'s/\x1b\[[0-9;]*[a-zA-Z]//g'
```

### Search engines

```bash
so -e startpage "query"       # Default — Google results via Startpage proxy
so -e stackexchange "query"   # Direct SE API (fastest, but weaker relevance)
so -e google "query"          # Broken — Google requires JS execution
so -e duckduckgo "query"      # Broken — DDG returns anomaly challenge
```

**Startpage** is the default and recommended engine. It proxies Google results as static HTML. StackExchange API is fastest but has weaker search relevance.

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

## Configuration

Config file: `~/Library/Application Support/io.Sam-Tay.so/config.yml`

```yaml
api_key: 8o9g7WcfwnwbB*Qp4VsGsw((
limit: 20
lucky: true
sites:
- stackoverflow
search_engine: startpage
copy_cmd: pbcopy
```

## Error Recovery

| Error | Type | Action |
|-------|------|--------|
| "Sorry, couldn't find any answers" | Query issue | Broaden search terms, try different phrasing |
| "DuckDuckGo blocked this request" | Permanent | Don't use `-e duckduckgo` — use startpage or stackexchange |
| "Crossterm error: Device not configured" | Environment | Not in a TTY — use `--print` instead of `--lucky` |
| "StackOverflow captcha check triggered" | Transient | Rare with `-e stackexchange`. Wait and retry |
| Rate limiting (300 req/day) | Transient | Register an API key: `so --set-api-key <key>` |

## Do NOT Use This For

- **Getting JSON/structured data** — `so` only outputs rendered text. If you need structured SO data, use the StackExchange API directly.
- **Posting questions or answers** — read-only tool.
- **Authenticated actions** — no login support (voting, commenting, etc.)

## Gotchas

- **Google and DuckDuckGo engines are dead.** Both now require JavaScript execution. Use `startpage` (default) or `stackexchange`.
- **`--lucky` requires a TTY.** Uses Crossterm spinner + raw mode. In scripts/agents, use `--print` instead.
- **`--print` implies `--lucky`.** It always fetches and prints the top answer.
- **No machine-readable output.** Everything is ANSI-rendered text. Strip with `sed $'s/\x1b\[[0-9;]*[a-zA-Z]//g'`.
- **Custom build.** The installed binary is from the DavidTeju/so fork, not the upstream Homebrew formula. `brew upgrade so` will overwrite it. Rebuild from `~/projects/so` if that happens.
- **No alias needed.** The `so` alias was removed — the config file sets `startpage` as the default engine directly.
