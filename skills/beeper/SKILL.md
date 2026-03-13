---
name: beeper
description: Cross-platform messaging CLI for Beeper Desktop. Access iMessage, WhatsApp, Instagram, LinkedIn, Telegram, Signal, Discord, Slack, and more from the terminal. Use when the user asks about messages, wants to search conversations, check unread, or send messages.
---

# beeper

**Always use `beeper` (the wrapper at `scripts/beeper`), never `beeper-desktop-cli` directly.**

The wrapper enriches iMessage phone numbers with contact names, does smart chat search across all scopes, and auto-loads the access token. Implementation details: `scripts/README-beeper.md`.

Requires Beeper Desktop running locally with API enabled (Settings > Developers).

## Auth Setup

1. Open Beeper Desktop → **Settings → Developers**
2. Ensure **Beeper Desktop API** is toggled on
3. Click the **"+"** next to **"Approved connections"** to generate an access token
4. Token is in `~/scripts/.env` as `BEEPER_ACCESS_TOKEN` (loaded by `~/.zshrc`)

To validate a token: `curl -X POST http://localhost:23373/oauth/introspect -d "token=<token>&token_type_hint=access_token"`

## Finding Chats

### Search by person name

```bash
# Find all chats with someone — works across ALL platforms including iMessage
beeper chats search --query "Lili"

# DMs only
beeper chats search --query "Lili" --type single

# Group chats only
beeper chats search --query "climbing" --type group
```

**What to expect:** Searching by name finds chats on every platform — Instagram, WhatsApp, AND iMessage. iMessage DMs show up with the contact's name (e.g. "Lili ❤️") even though Beeper stores them as phone numbers internally.

### Search by topic/keyword

```bash
beeper chats search --query "climbing"
beeper chats search --query "dinner" --type group
```

### Filter chats

```bash
# By inbox type
beeper chats search --inbox primary --limit 20

# Unread only
beeper chats search --unread-only true

# By time range
beeper chats search --last-activity-after "2026-02-01T00:00:00Z"

# By account (e.g. just WhatsApp)
beeper chats search --account-id <accountId>
```

### Get specific chat

```bash
beeper chats retrieve --chat-id <chatId>
```

### List recent chats

```bash
beeper chats list
beeper chats list --max-items 20
```

## Finding Messages

```bash
# Search across all chats
beeper messages search --query "lunch"

# Search within a specific chat
beeper messages search --chat-id <chatId> --query "address"

# Messages from others only (find unanswered stuff)
beeper messages search --query "free" --sender others

# Your own messages (find promises you made)
beeper messages search --query "should" --sender me

# Filter by date range
beeper messages search --date-after "2026-02-15T00:00:00Z" --date-before "2026-03-01T00:00:00Z"

# DMs only (skip group noise)
beeper messages search --query "tea" --chat-type single

# Messages with media
beeper messages search --media-type image
beeper messages search --media-type video
beeper messages search --media-type any

# Exclude muted/low-priority
beeper messages search --query "plans" --include-muted false --exclude-low-priority true

# List messages in a chat (newest first)
beeper messages list --chat-id <chatId>
```

## Unified Search

Quick search across chats, participants, and messages in one call:

```bash
beeper search --query "dinner"
```

## Sending Messages

**Always confirm with Femi before sending.**

```bash
# Send a text
beeper messages send --chat-id <chatId> --text "On my way!"

# Reply to a specific message
beeper messages send --chat-id <chatId> --text "Sounds good" --reply-to-message-id <msgId>

# Send with attachment
beeper messages send --chat-id <chatId> --text "Check this out" --attachment /path/to/file.png

# Edit a sent message
beeper messages update --chat-id <chatId> --message-id <msgId> --text "corrected text"
```

## Reactions

```bash
beeper chats:messages:reactions add --chat-id <chatId> --message-id <msgId> --reaction-key "👍"
beeper chats:messages:reactions delete --chat-id <chatId> --message-id <msgId> --reaction-key "👍"
```

## Reminders

```bash
beeper chats:reminders create --chat-id <chatId> --remind-at "2026-03-10T09:00:00Z"
beeper chats:reminders delete --chat-id <chatId>
```

## Focus (open Beeper Desktop to a chat)

```bash
beeper focus
beeper focus --chat-id <chatId>
beeper focus --chat-id <chatId> --draft-text "Hey, are you free this weekend?"
```

## Accounts & Contacts

```bash
beeper accounts list
beeper accounts:contacts list --account-id <accountId>
beeper accounts:contacts search --account-id <accountId> --query "Sarah"
```

## Output Formats

All formats: `auto`, `explore`, `json`, `jsonl`, `pretty`, `raw`, `yaml`. Default is `pretty`.

```bash
beeper chats list --format json        # single JSON array
beeper chats list --format jsonl       # one JSON object per line (best for scripting)
beeper messages search --query "dinner" --format yaml
```

**What to expect:** All formats get contact enrichment — iMessage phone numbers are replaced with contact names regardless of format.

## Pagination

```bash
# First page
beeper chats list --format json
# → response includes "cursor" field

# Next page (older results)
beeper chats list --cursor <cursor> --direction before

# Newer results
beeper chats list --cursor <cursor> --direction after
```

## Shell Quoting for Chat IDs

Chat IDs contain special shell characters.

**`!` (Matrix rooms):** Use `$'...'` syntax to prevent zsh history expansion:
```bash
CHAT_ID=$'!roomId:server.com'
beeper chats retrieve --chat-id "$CHAT_ID"
```

**`##` (iMessage):** Handled automatically by the wrapper. Just pass the raw chat ID.

## Gotchas

- `--query` is **literal token matching**, not semantic. Use single words ("dinner" not "dinner plans"). Multiple words = ALL must match.
- **Don't pass `--scope` to `chats search`** unless you specifically want to restrict results. Without it, the wrapper searches titles + participants + reverse phone lookup automatically. The raw CLI's default scope is unreliable.
- `beeper messages search` searches message **content**. `beeper chats search` searches chat **titles/participants**.
- Beeper Desktop must be running locally — the CLI hits `localhost:23373`.
- `--debug` flag shows raw HTTP requests/responses for troubleshooting.
