---
name: femi-calendar
description: |
  Manage Femi's Google Calendar schedule. Use when:
  (1) adjusting today's schedule (running late, skipping something, pushing blocks),
  (2) modifying recurring events (move climbing, change gym day),
  (3) adding one-off events, (4) checking what's on the calendar.
  Contains all verified addresses, color codes, commute data, and constraints.
author: Ori
---

# Femi's Calendar Management

## Quick Reference

**Calendar ID:** `<primary-email>`
**Tool:** `gog` CLI (`/opt/homebrew/bin/gog`)
**Timezone:** America/Los_Angeles (PST/PDT)
**Schedule design doc (Notion):** https://www.notion.so/3130290a8d0d81eb9a49ffa2610cd393

## When to Check the Notion Design Doc

This skill handles day-to-day adjustments. Fetch the Notion design doc when:
- **Changing the recurring structure** (moving climbing to a different day, swapping gym days, changing wake time)
- **Something doesn't make sense** ("why does Thursday end work at 4:15?") — the doc has the reasoning
- **Adding a new recurring commitment** (need to check what trade-offs were made and what's flexible)
- **Femi asks "why is it like this?"** — the doc has the design rationale and trade-offs
- **Seasonal adjustments** (DST, daylight changes, weather affecting bike commute)

## Common Operations

### Push today's schedule back (running late)

1. Find today's events:
```bash
gog calendar events <primary-email> --today --json --no-input
```

2. Update specific instances (NOT the series — use the instance ID with date suffix):
```bash
gog calendar update <primary-email> <instanceId> \
  --from "2026-03-02T08:00:00-08:00" --to "2026-03-02T08:30:00-08:00" \
  --force --no-input
```

3. Key rule: **Don't move the end of work.** Push morning blocks forward, compress or skip flexible blocks (buffer, free time), keep work end time fixed. Evening blocks stay anchored.

4. Blocks safe to compress/skip: BUFFER, free time, Duolingo (do later), messages
5. Blocks NOT to compress: skincare (wait times are real), work, climbing, Tea with X, calls

### Skip a recurring event this week only

Delete the single instance, not the series:
```bash
gog calendar delete <primary-email> <instanceId> --scope=single \
  --original-start "2026-03-05T17:25:00-08:00" --force --no-input
```

### Add a one-off event

```bash
gog calendar create <primary-email> \
  --summary "Event Name" \
  --from "2026-03-05T18:00:00-08:00" --to "2026-03-05T19:00:00-08:00" \
  --event-color 6 --force --no-input
```

### Modify a recurring event permanently

Update the base event (no date suffix in ID):
```bash
gog calendar update <primary-email> <baseEventId> \
  --from "2026-03-02T09:00:00-08:00" --to "2026-03-02T10:00:00-08:00" \
  --force --no-input
```

### List calendars
```bash
gog calendar calendars --no-input
```
Calendars: Personal (primary), Run Club, Runna, Partiful, Holidays in US

## Color Coding

| Color ID | Color   | Use For |
|----------|---------|---------|
| 9        | Blue    | Work, Deep Work |
| 10       | Green   | Exercise (run, bike, climbing, gym) |
| 2        | Teal    | Commute/transit (connector, bus — reading time) |
| 6        | Orange  | Social (Tea with X, dinner, calls) |
| 11       | Red     | Strict/important (Weekend planning) |
| 5        | Yellow  | Chores, grocery, meal prep |
| 3        | Purple  | Personal routine (skincare, shower, dress) |
| 7        | Cyan    | Free time, buffer, lunch, messages, Duolingo |
| 8        | Gray    | Sleep |

## Event Granularity

Femi wants **every block as its own event** — NOT consolidated. "AM skincare" is one event, "Dress + take Adderall" is another, etc. When creating new events, match this granularity.

## Verified Addresses

| Location | Address | Notes |
|----------|---------|-------|
| Home | See USER.md current address | Capitol Hill |
| Connector pickup (AM) | Bellevue Ave & E Pike St, Seattle, WA | ~5 min bike from home |
| Connector pickup (alt) | 19th Ave E & E Harrison St, Seattle, WA | ~5 min bike, earlier departure |
| Microsoft campus | 3720 159th Ave NE, Redmond, WA 98052 | Building 34 |
| Commons Transit Center | On Microsoft campus, Redmond | Connector pickup/dropoff |
| Redmond Transit Center | 8178 161st Ave NE, Redmond, WA 98052 | 542 bus, Bay 5. **1.3 mi from campus — 8 min bike** |
| Redmond Technology Station | 3929 156th Ave NE, Redmond, WA 98052 | Light rail. **NOT the same as Redmond TC** |
| SBP U-District | 4502 University Way NE, Seattle, WA 98105 | Tuesday climbing |
| SBP Fremont | 3535 Interlake Ave N, Seattle, WA 98103 | Thursday climbing |
| PCC Capitol Hill | 1020 E John St, Seattle, WA | Grocery |
| Planet Fitness Ballard | 1500 NW Market St, Seattle, WA 98107 | Rotates |
| Planet Fitness Aurora | 13201 Aurora Ave N, Seattle, WA 98133 | Rotates |
| Planet Fitness Rainier | 9000 Rainier Ave S, Seattle, WA 98118 | Rotates |

## Commute Timing

### Morning connector (Tue/Wed/Thu)
- Bike to Bellevue & Pike: 5 min
- Connector departures from Bellevue & Pike: 7:52, 8:07, 8:17, 8:27, 8:37...
- **Target: 8:07 AM** (primary). Fallback: 8:17 (arrive 9:08, still fine)
- Ride to CTC: ~41 min. Bike to office: ~5 min.

### Tuesday evening (climbing)
- Bike from campus to Redmond TC: 8 min (1.3 mi)
- 542 bus departures from Redmond TC: 4:27, 4:38, 5:00, 5:21, 5:51...
- **Target: 5:00 PM** bus. Arrive U-District 5:40. Bike to SBP 5 min.
- Return: Link light rail (default) or bike uphill (25 min, only if dry + strong)

### Wednesday evening (home)
- Connector from CTC: 5:00 PM → 19th & Harrison 5:41. Bike home 5 min.

### Thursday evening (climbing)
- Bike from campus to CTC: 3 min
- Fremont connector departures: 3:01, 3:34, 4:11, **4:28**, 4:56, 5:21, 5:57 (LAST)
- **Target: 4:28 PM** connector. Arrive Wallingford & N 34th 5:19. Bike to SBP 3 min.
- **Only 7 departures total.** Limited service — don't miss the window.
- Return: Bike home via Eastlake, 20 min (mostly flat)

## Hard Rules

- **Never Uber/Lyft.** Not negotiable.
- **Doesn't drink coffee.** Tea.
- **No meds (Adderall) on weekends.** Saturday and Sunday events say "Dress" not "Dress + meds."
- **Night showers preferred.** Showers after every workout. Skip night shower only if morning workout next day.
- **Body skincare follows the shower.** AmLactin + Relumins + SPF go on clean skin. Morning shower days (Mon/Fri): body skincare AM. Night shower days (Tue/Wed/Thu/Sat/Sun): body skincare PM after shower. Never apply body products without showering first.
- **No PhD events.** Removed permanently.
- **Connector time = reading time.** Don't schedule anything on top of it.
- **Dinner after climbing = 45 min.** Not longer.
- **Climbing pattern:** 2h climb → 15m stretch → 15m pack up → 45m dinner → commute home
- **ADHD buffer: 15-20 min max.** More = phone trap. Less = cascade failure.
- **No vague blocks.** "Free time (2 hrs)" is a paralysis trap for ADHD without meds. Every block needs either a specific activity OR a short menu of concrete options in the description (e.g., "Pick one: hike Volunteer Park / personal project / cold plunge at Montlake / read at a cafe"). Especially on weekends (no Adderall).
- **38+ hrs/week work is fine.** No need to pad.

## Schedule Structure (by day)

| Day | Type | Morning | Commute | Evening |
|-----|------|---------|---------|---------|
| Mon | Remote | Run 6:00-6:55 | None | Chores + Cook |
| Tue | Office | Skincare (no shower) | Connector → 542 bus | Climbing U-District + Dinner |
| Wed | Office | Skincare (no shower) | Connector both ways | Tea with X |
| Thu | Office | Skincare (no shower) | Connector → Fremont connector | Climbing Fremont + Dinner |
| Fri | Remote | Bike 6:00-7:00 | None | Weekend Planning + Chores |
| Sat | Free | Optional run | Drive | Grocery + Gym |
| Sun | Free | Free time | Drive | Calls + Meal Prep + Gym |

## Shower Logic

**Rule:** One shower per day, after workout. No-workout days default to night shower. Skip night shower only if next morning has a workout (you'll shower then).

| Day | Workout | Shower | Why |
|-----|---------|--------|-----|
| Mon | Run (AM) | After run | Workout shower = day's shower |
| Tue | Climbing (PM) | After climbing, at home | Post-workout |
| Wed | None | Night, before PM skincare | No workout → default night |
| Thu | Climbing (PM) | After climbing, at home | Post-workout |
| Fri | Bike (AM) | After bike | Workout shower = day's shower |
| Sat (run) | Run + PF | After each | Two workouts = two showers |
| Sat (no run) | PF (PM) | After PF | Post-workout |
| Sun | PF (PM) | After PF | Post-workout |
