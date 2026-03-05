---
name: notion-style-matching
description: |
  Match David's specific Notion formatting preferences when creating content. Use when:
  (1) creating new pages in David's Notion workspace, (2) user says content
  is "over-formatted" or doesn't match their style, (3) starting any Notion
  content creation task. This skill contains David's actual preferences learned
  from 30+ pages across his workspace - tables, checkboxes, toggles, bold headers,
  casual tone, databases for tracking.
author: Claude Code
user-invocable: false
---

# Notion Style Matching (David's Workspace)

## Problem
Creating Notion content with formatting that doesn't match David's established style.
David uses a specific mix of structured elements (tables, databases, checkboxes) with
casual note-taking tone. Over-formatting with excessive markdown headers or formal
documentation style feels out of place.

## Context / Trigger Conditions
- Creating a new page in David's Notion workspace
- User feedback like "too formatted", "doesn't match my style"
- Any substantial content creation in Notion

## David's Formatting Patterns (Learned from 30+ pages)

### Structure & Organization

**Databases are heavily used for tracking:**
- Todo List (Status, Category, Labels, Deadline)
- Notes (general catch-all)
- Journal (Date, Name, Odometer reading)
- Shopping List (Type, Date bought)
- Projects (Name, Tags)
- Destinations (Location Name, State, Dates, Chaperone)

**Page organization:**
- Subpages for related content
- Embedded/inline databases within pages
- Columns layout for side-by-side content

### Tables

**Use tables WITH headers for:**
- Structured reference data (Faculty lists with School, Focus columns)
- Timeline/schedule planning (Phase, Dates, Focus)
- Weekly time budgets (Activity, Hours, Notes)
- Decision matrices (Risk, Mitigation)
- Product comparisons (Product, Purpose, Where to Buy, Notes)

**Table style:**
```
<table header-row="true">
<tr><td>Column 1</td><td>Column 2</td><td>Column 3</td></tr>
<tr><td>data</td><td>data</td><td>data</td></tr>
</table>
```

### Text Formatting

**Headers:**
- Prefer **bold text** for section headers over markdown `#`
- When markdown headers used, typically `#` or `##` only
- Example: `**FACE PRODUCTS**` not `### Face Products`

**Toggles (▶) for collapsible sections:**
- Very common in travel and planning pages
- Format: `▶ Section title` with indented content below
- Used for: roadmaps, packing categories, old/archived content

**Checkboxes extensively for:**
- Todo items: `- [ ] Task`
- Packing lists
- Shopping lists
- Action items
- Purchase status tracking

**Dividers (`---`):**
- Between major sections
- Not between every small section

**Indentation:**
- Heavy use of tab indentation for hierarchy
- Nested bullet points for sub-items
- Day-by-day itineraries use numbered labels then indented content:
  ```
  15:
      Task 1
      Task 2
  16:
      Task 1
  ```

**Colored text/highlights:**
- Used sparingly for emphasis
- Example: `<span color="green_bg">*Alaska*</span>`

### Content Style by Page Type

**Planning pages (PhD thinking, Grad trip, Apartment search):**
- Tables for structured data
- Checklists for action items
- Toggles for collapsible sections
- Multiple embedded databases
- Detailed but scannable

**Reference pages (Reading List, Bookmarks, Links):**
- Simple lists of links
- Minimal formatting
- Just `[Title](url)` entries

**Journal entries:**
- Prose paragraphs
- Embedded images
- Personal/reflective tone
- Minimal formatting within

**Trip/Destination pages:**
- Day-by-day itineraries with numbered days
- Bullet points for activities
- Links to maps and resources
- Packing lists with checkboxes

**Quick notes (Sex, Casual goals, Goals planning):**
- Plain text lines
- Minimal to no formatting
- Just ideas/thoughts listed

**Decision/analysis pages (Weekend possibilities):**
- Tables with conditional matrices
- "If X then Y" structures

### Icons/Emojis

**Page icons used:**
- Cooking: 🍳
- Work: 💼
- Cities: 🌆
- Food prep: 🥔
- Todo: ✔️
- Journal: 📙
- Projects: 🏗️
- Bucket list: 🪣
- Bored: 💤
- Destinations: ⛳, ⛰️
- Fun: 🎳
- Thinking: 🧠

**In content:** Used sparingly, only when meaningful

### What NOT to Do

- Over-formatted markdown headers (`###`, `####`)
- Excessive bold/italic throughout
- Formal documentation tone for personal notes
- Heavy structure for simple idea lists
- Adding explanatory text when bullet points suffice

## Solution Template

**For a routine/protocol page (like Skincare):**
```
Goal: [one line description]
[Brief context if needed]

---
**SECTION NAME**
- [ ] Checkbox item (for tracking)
- [ ] Another item

**PRODUCTS/ITEMS**
<table header-row="true">
<tr><td>Item</td><td>Purpose</td><td>Source</td><td>Notes</td></tr>
<tr><td>Product 1</td><td>What it does</td><td>Where to buy</td><td>Important detail</td></tr>
</table>

---
**ROUTINE/STEPS**
1. Step one
2. Step two (note about timing)
3. Step three

---
**NOTES/WHY**
- Bullet point explanation
- Another reason
- Key insight

---
**STATUS**
Buying now:
- [x] Item purchased
- [x] Another item

Still need:
- [ ] Item to buy
- [ ] Another item
```

**For a trip/destination page:**
```
Day 1:
    Activity 1
    Activity 2 at **Place Name**
    [Link to map](url)

Day 2:
    Morning: activity
    Afternoon: activity
    Evening: activity

---
Packing:
- [ ] Item 1
- [ ] Item 2
▶ Category
    - [ ] Sub-item
    - [ ] Sub-item
```

**For quick reference/notes:**
```
Just plain text lines
Another thought
A link if relevant: [text](url)
```

## Verification
After creating content, fetch the page to verify it rendered correctly and matches
the style patterns above.

## Notes
- Style varies by page type - match the relevant type
- Simpler is better for personal reference content
- Tables are welcome and frequently used - don't avoid them
- Checkboxes are preferred for any trackable items
- When content goes under a database, use the database's existing property schema
