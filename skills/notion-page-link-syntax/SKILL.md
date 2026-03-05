---
name: notion-page-link-syntax
description: |
  Fix Notion MCP URL validation errors when updating page content with links. Use when:
  (1) "Invalid agent URL - Failed to parse as URL" error with {{URL}} syntax,
  (2) need to link to existing page without moving it, (3) replacing plain text with page references.
  Covers difference between <page> vs <mention-page> tags and read vs write URL formats.
author: Claude Code
user-invocable: false
---

# Notion Page Link Syntax for MCP Updates

## Problem
When using the Notion MCP `update-page` tool to insert page links, the URL format shown in
fetched content doesn't work for writes, causing validation errors.

## Context / Trigger Conditions
- Error: `"Invalid agent URL - Failed to parse as URL: {{https://www.notion.so/...}}"`
- Using `notion-update-page` with `replace_content_range` or `insert_content_after`
- Trying to replace plain text with a link to another Notion page
- Content fetched from Notion shows URLs wrapped in `{{...}}`

## Solution

### 1. URL Format Differs Between Read and Write

**When reading/fetching** - URLs appear wrapped:
```
<page url="{{https://www.notion.so/abc123}}">Page Title</page>
```

**When writing/updating** - Use plain URLs without braces:
```
<page url="https://www.notion.so/abc123">Page Title</page>
```

### 2. Choose the Right Tag for Your Intent

**`<page>`** - Creates a child page or MOVES an existing page:
```markdown
<page url="https://www.notion.so/abc123">Page Title</page>
```
WARNING: Using `<page>` with an existing URL will MOVE that page to become a child of the current page.

**`<mention-page>`** - Creates an inline mention/link without moving:
```markdown
<mention-page url="https://www.notion.so/abc123">Page Title</mention-page>
```
Use this when you just want to reference/link to a page.

### 3. Practical Example

To replace plain text "Cooking" with a link to an existing page:

**Wrong** (causes validation error):
```json
{
  "new_str": "<page url=\"{{https://www.notion.so/abc123}}\">Cooking</page>"
}
```

**Wrong** (moves the page instead of linking):
```json
{
  "new_str": "<page url=\"https://www.notion.so/abc123\">Cooking</page>"
}
```

**Correct** (creates a link without moving):
```json
{
  "new_str": "<mention-page url=\"https://www.notion.so/abc123\">Cooking</mention-page>"
}
```

## Verification
- No validation error on the API call
- Fetch the updated page to confirm the link appears correctly
- Verify the linked page wasn't moved (check its parent is unchanged)

## Notes
- The `<mention-page>` inner text (page title) is optional; Notion displays the actual title
- Self-closing format also works: `<mention-page url="https://www.notion.so/abc123"/>`
- Same principle applies to `<mention-database>` and `<mention-user>` tags
- Always fetch pages before editing to understand their current structure
