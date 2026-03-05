---
name: message-review
description: |
  Scan messages for action items, unanswered questions, and unfulfilled plans. Use when:
  (1) user asks to check messages, review inbox, or find things they forgot to respond to,
  (2) morning briefing or daily check-in, (3) user says "what am I forgetting?" or
  "who do I need to get back to?", (4) user wants to find promises they made but didn't
  fulfill. Scans Beeper messages across all platforms, resolves contacts, prioritizes by
  recency/frequency, outputs to both Notion and Markdown.
author: Claude Code
---

# Message Review

Scan messages for action items you might have forgotten about.

## When to Use

- User explicitly calls `/message-review`
- Part of morning briefing routine
- User asks: "check my messages", "who do I need to respond to?", "what am I forgetting?"
- User mentions unfulfilled social plans

## Configuration

| Setting | Value |
|---------|-------|
| Time range | 2 weeks |
| Platforms | All Beeper (iMessage, WhatsApp, Instagram, LinkedIn, etc.) |
| Exclusions | Group chats with 10+ participants |
| Priority | Recency/frequency of contact |
| Output | Notion Todo List + Markdown file |

## Action Item Categories

### 1. Unanswered Questions
Messages where someone asked you a direct question and you haven't responded.

**Detection patterns:**
- Messages ending in `?` that aren't from you
- Messages with question words (what, when, where, who, how, why, can you, will you, do you)
- Last message in thread is from someone else asking something

### 2. Your Unfulfilled Plans
Plans YOU initiated or proposed that never got finalized.

**Detection patterns:**
- Your messages containing: "we should", "let's", "want to", "how about", "I'd love to"
- Followed by no concrete date/time being set
- Keywords: tea, coffee, lunch, dinner, drinks, hang out, climb, hike, ski

### 3. Others' Proposals
Plans others suggested that you didn't respond to or confirm.

**Detection patterns:**
- Their messages with plan language directed at you
- Your last response was non-committal or absent
- Keywords: "want to", "should we", "are you free", "come to"

### 4. Time-Sensitive Items
Appointments, RSVPs, deadlines mentioned in messages.

**Detection patterns:**
- Dates and times mentioned
- Words: appointment, confirm, RSVP, deadline, by [date], reminder
- Medical/service appointment confirmations waiting for reply

## Execution Steps

### Step 1: Fetch Recent Chats
```bash
beeper chats search --inbox primary --limit 50 --format json
# Filter out groups with 10+ participants from results
```

### Step 2: Scan Messages
For each relevant chat:
```bash
beeper messages list --chat-id <chatId> --format json
# Analyze for action item patterns above
```

### Step 3: Prioritize
Contact names are already resolved by the beeper wrapper (uses `scripts/lookup-contacts` Swift binary).

Sort action items by:
1. **Urgency**: Time-sensitive items first (appointments within 7 days)
2. **Recency**: More recent messages rank higher
3. **Frequency**: People you message often rank higher than dormant contacts

### Step 5: Generate Output

#### Markdown File
Save to: `message_action_items.md`
```markdown
# Message Action Items & Unfulfilled Plans
*Generated: [date]*

## High Priority
| # | Action | Contact | Details | Status |
...

## Unfulfilled Plans
...
```

#### Notion Task
Create in Todo List database:
- Name: "Review message action items and respond to friends"
- Category: Social
- Labels: Phone
- Body: Checklist of all action items

### Step 6: Open Results
- Open markdown file in VS Code
- Provide Notion task URL

## Example Output

### High Priority
| # | Action | Contact | Details |
|---|--------|---------|---------|
| 1 | Confirm medical appointment | Dr. Office | Reply Y for Jan 27 2:10pm |
| 2 | Reply about lunch | Ian | "lemme know what works" |
| 3 | Respond to Swathi | Swathi | She asked "how are you?" |

### Unfulfilled Plans
| Date | Contact | Your Promise | Status |
|------|---------|--------------|--------|
| Jan 17 | Will Fang | "I'd love to have tea" | NOT SCHEDULED |
| Jan 24 | Ian | "lunch next week?" | NEEDS DATE |

## Integration Points

### Current
- **beeper**: Message access across platforms (CLI)
- **Notion MCP**: Todo list creation
- **lookup-contacts**: Phone number resolution (Swift binary, called by beeper wrapper)

### Future (when available)
- **Calendar MCP**: Cross-reference plans with calendar events
- **Email MCP**: Scan for related action items in email
- **Reminders MCP**: Create follow-up reminders

## Notes

- Run time: ~30-60 seconds depending on message volume
- Beeper must be running for MCP access
- Contact resolution uses macOS Contacts via Swift binary (requires Contacts permission)
- Large group chats (10+) are excluded to reduce noise
- Results become stale - regenerate as needed

## Troubleshooting

### "No messages found"
- Ensure Beeper Desktop is running
- Verify `BEEPER_ACCESS_TOKEN` is set
- Test: `beeper chats list --limit 1 --format json`

### Contact resolution fails
- Grant Automation permission to Terminal/VS Code for Contacts app
- Test: `scripts/lookup-contacts "+1 555-123-4567"`

### Notion task creation fails
- May need to use API fallback if MCP is unreliable
- Check Notion MCP connection
