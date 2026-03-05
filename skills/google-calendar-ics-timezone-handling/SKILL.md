---
name: google-calendar-ics-timezone-handling
description: |
  Handle timezone issues with imported/subscribed Google Calendar ICS feeds when using
  the `gog` CLI tool. Use when: (1) work calendar events show meetings at absurd times
  like 11 PM or 4 AM, (2) calendar has an `@import.calendar.google.com` ID suffix,
  (3) work meeting times don't make sense as local times but make perfect sense as UTC,
  (4) using `gog calendar events` on any non-primary calendar. Root cause: imported ICS
  feeds (from Microsoft Outlook, Exchange, etc.) store times in UTC. The `gog` tool returns
  these raw UTC times without converting to the user's local timezone. Primary/native
  Google Calendar events DO include timezone offsets (e.g., `-08:00` for PST).
author: Claude Code
user-invocable: false
---

# Google Calendar ICS Timezone Handling

## Problem
When reading calendar events via `gog calendar events`, imported/subscribed calendars
(typically work calendars synced from Microsoft Outlook/Exchange) return times in UTC,
not the user's local timezone. This causes meetings to appear at nonsensical times
(e.g., a morning standup showing at 11:05 PM, an afternoon focus block showing at
11:00 PM-1:00 AM).

## Context / Trigger Conditions
- Calendar ID ends in `@import.calendar.google.com` (imported ICS feed)
- Event times look absurd (meetings at 11 PM, 4 AM, midnight)
- Raw JSON dateTime fields end in `Z` (UTC) instead of timezone offset like `-08:00`
- Primary Google Calendar events show correct local times but work calendar doesn't
- The user has a synced Microsoft Outlook/Exchange work calendar

## Solution

### Detection
1. Check the calendar ID. If it ends in `@import.calendar.google.com`, it's an imported feed.
2. Look at raw JSON: if dateTime values end in `Z`, times are UTC.
3. Compare: native Google Calendar events will have explicit offsets like `2026-02-26T08:15:00-08:00`.

### Conversion
- **PST (Nov-Mar)**: Subtract 8 hours from displayed time. `23:05 UTC = 15:05 PST (3:05 PM)`
- **PDT (Mar-Nov)**: Subtract 7 hours. `23:05 UTC = 16:05 PDT (4:05 PM)`
- **DST transition date changes yearly** — typically second Sunday of March and first Sunday of November

### Critical: DST Shifts Affect Recurring Meeting Times
After Daylight Saving Time starts (e.g., March 9, 2026), meetings stored in UTC will
appear 1 hour LATER in local time:
- A meeting at 23:00 UTC = 15:00 PST (3 PM) → 16:00 PDT (4 PM) after DST
- This can create new scheduling conflicts that didn't exist before DST

### Sanity Check
If a converted time doesn't make sense (e.g., a team standup at 11 PM local time),
the original time might actually be in IST (UTC+5:30) or another timezone, indicating
a meeting scheduled for a team in a different region. Conference room names can help
disambiguate (e.g., "HYD-PHOENIX" = Hyderabad, India).

## Verification
After converting, verify that meeting times make contextual sense:
- Standups/scrums → morning (9-11 AM local)
- 1:1s with manager → business hours
- Focus/coding blocks → afternoon
- Cross-timezone meetings → check conference room location in the event

## Example

```
Raw from gog:  "Evo Scrum" at 18:00-18:30 (appears to be 6:00-6:30 PM)
Calendar ID:   hfk927l...@import.calendar.google.com
Raw JSON:      "dateTime": "2026-02-24T18:00:00Z"  (note the Z = UTC)

Conversion:    18:00 UTC - 8h = 10:00 AM PST
Result:        Evo Scrum is at 10:00-10:30 AM PST (makes sense as a morning standup)
```

```
Raw from gog:  "[Energy drink] Code monkey Code" at 23:00-01:00
Conversion:    23:00 UTC - 8h = 15:00 PST (3:00 PM)
               01:00 UTC - 8h = 17:00 PST (5:00 PM)
Result:        Afternoon focus coding block, 3-5 PM PST (makes perfect sense)
```

## Notes
- This affects ALL imported calendars, not just Microsoft. Any ICS subscription
  (Outlook, Apple Calendar, Calendly) may exhibit this behavior.
- The `gog` tool does NOT auto-detect or warn about this. You must check the calendar ID.
- When building schedules around work meetings, ALWAYS convert first, then check for
  conflicts. Multiple agents in this session flagged "meeting conflicts" that were
  actually phantom issues from unconverted UTC times.
- Primary Google Calendar events (user-created) are NOT affected — they include
  explicit timezone offsets in the JSON.
