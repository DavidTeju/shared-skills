---
name: x-cli
description: |
  X/Twitter CLI for reading timelines, searching tweets, checking engagement,
  streaming, and managing lists. Use when: (1) user asks about tweets, Twitter,
  or X, (2) checking mentions or engagement, (3) searching Twitter discussions,
  (4) streaming tweets by keyword, (5) looking up users or followers.
user-invocable: false
allowed-tools:
  - Bash
  - Read
  - Agent
---

# x-cli (Homebrew `x`)

CLI for X/Twitter. Installed via `brew install x-cli`, binary is `x`.
Authenticated as **@DavidTejuo** (read-only).

## Quick Start

- **Auth config:** `~/.xrc` (YAML, chmod 600)
- **Verify:** `x whoami`
- **Output formats:** Default is human-readable table. Use `-c` for CSV (machine-parseable), `-l` for long/detailed.
- **No JSON output.** CSV (`-c`) is the structured format. All list commands support it.

## Core Workflows

### Read Timeline

```bash
# Your own recent tweets
x timeline @DavidTejuo

# Someone else's timeline
x timeline @elikirosho

# CSV for parsing (columns: ID, Posted at, Screen name, Text)
x timeline -c @DavidTejuo
# Returns: ID,Posted at,Screen name,Text
# 2032572504297152533,2026-03-13 21:40:23 +0000,DavidTejuo,"Tweet text here"

# Long format (adds ID column to table view)
x timeline -l @DavidTejuo
```

### Check Mentions & Engagement

```bash
# Recent mentions (tweets @-ing you)
x mentions

# Specific tweet details + engagement
x status 2032572504297152533
# Returns: ID, Text, Screen name, Posted at, Retweets, Favorites, Source

# CSV for a specific tweet
x status -c 2032572504297152533

# Estimated reach of a tweet
x reach 2032572504297152533

# Your recent likes
x favorites
x favorites -n 50  # up to 50
```

### Search

```bash
# Search recent tweets (20 results default)
x search all "claude code"

# More results
x search all -n 50 "AI agents"

# Search within your mentions
x search mentions "hook"

# Search within your timeline
x search timeline "backpacking"

# CSV output for parsing
x search all -c "seattle climbing"
# Returns: ID,Posted at,Screen name,Text
```

### User Lookup

```bash
# Profile info
x whois @elikirosho
# Returns: ID, Since, Screen name, Name, Tweets, Favorites, Listed, Following, Followers, Bio, URL

# CSV for parsing
x whois -c @elikirosho
# Columns: ID,Since,Last tweeted at,Tweets,Favorites,Listed,Following,Followers,Screen name,Name,Verified,Protected,Bio,Status,Location,URL

# Your own profile
x whoami
```

### Social Graph

```bash
# Who follows you
x followers

# Who you follow
x followings

# Mutual follows
x friends

# Sort by followers count, CSV
x followers -c -s followers

# Check if someone follows someone
x does_follow @user1 @user2
```

### Streaming (Real-Time)

```bash
# Stream tweets matching keywords (Ctrl-C to stop)
x stream search "AI agents" "claude code"
# WARNING: Keywords are OR'd, not AND'd

# Stream your timeline in real-time
x stream timeline

# Stream specific users' tweets
x stream users @elikirosho @anthropaborine

# Limit events (useful for scripting)
X_STREAM_MAX_EVENTS=10 x stream search "seattle"

# CSV streaming output
x stream search -c "keyword"
```

### Lists

```bash
# Your lists
x lists

# Members of a list
x list members "my-list"

# Timeline from a list
x list timeline "my-list"
```

## Command Quick Reference

| Command | Description |
|---------|-------------|
| `x whoami` | Your profile |
| `x whois @user` | User profile lookup |
| `x timeline @user` | Recent tweets |
| `x mentions` | Tweets mentioning you |
| `x status ID` | Single tweet details |
| `x reach ID` | Tweet reach estimate |
| `x favorites` | Your liked tweets |
| `x search all "query"` | Search recent tweets |
| `x followers` | Your followers |
| `x followings` | Who you follow |
| `x friends` | Mutual follows |
| `x lists` | Your lists |
| `x stream search "kw"` | Real-time keyword stream |
| `x trends` | Top 50 trending topics |

## Safety

| Tier | Commands | Notes |
|------|----------|-------|
| Always safe | timeline, mentions, search, whois, whoami, followers, followings, friends, favorites, status, reach, trends, lists, stream | All read-only |

**Current token is read-only.** Write operations (update/post, reply, retweet, favorite, follow, dm, delete) will return 403.

## Error Recovery

| Error | Action |
|-------|--------|
| "No active credentials found in profile" | `~/.xrc` missing or malformed. Bug in v5.0.0: `x authorize` also fails with this. Manually create `~/.xrc` with credentials first. |
| "Unauthorized" | Token expired or revoked. Regenerate on developer.x.com and update `~/.xrc`. |
| "Rate limited" / 429 | Wait 15 minutes. Search and timeline endpoints are rate-limited. |
| Empty output | User may have no tweets, no followers, etc. Not an error. |

## Gotchas

- **Binary is `x`, not `x-cli`.** `brew install x-cli` installs the `x` command.
- **No JSON output.** Use `-c` (CSV) for machine-readable output. No `--json` flag exists.
- **`-c` is CSV, `-C` is color.** Case-sensitive. Don't confuse them.
- **Global flags before subcommand.** `-c` goes after the command: `x timeline -c @user`, not `x -c timeline @user`.
- **Tweet IDs are numeric strings.** 19 digits, e.g. `2032572504297152533`. Pass as-is.
- **`-n` flag** controls result count (default 20). Only on search/favorites commands, not timeline.
- **Stream keywords are OR'd.** `x stream search "AI" "agents"` matches tweets with "AI" OR "agents", not both.
- **`x authorize` is broken in v5.0.0** when no profile exists. Workaround: manually write `~/.xrc`. See error recovery above.
- **Aliases:** `tweet`/`post` = `update`, `tl` = `timeline`, `faves` = `favorites`, `rt` = `retweet`, `replies` = `mentions`.
- **OpenClaw has a different Python `x-cli`** (installed via `uv tool`). Different tool, different flags, different auth (env vars). This skill covers only the Homebrew Rust version.

## Do NOT Use This For

- **Posting tweets** — Token is read-only. Would need permission upgrade + token regeneration.
- **Sending DMs** — Read-only, and Beeper covers all messaging.
- **Analytics dashboards** — Use Twitter's native analytics at analytics.x.com.
- **Bulk data export** — API rate limits make this impractical. Use Twitter's data export feature instead.
