---
name: querying-and-updating-notion
description: |
  REQUIRED before ANY Notion operation. Determines whether to use MCP tools or direct API.
  Use when: (1) about to use ANY Notion MCP tool (notion-search, notion-fetch, notion-update-page,
  notion-create-pages), (2) user asks to query, update, create, or organize Notion content,
  (3) need to list all items in a database (MCP CANNOT do this - only API can), (4) bulk
  updating 5+ pages (API is faster), (5) updating page icons/covers (only API supports this),
  (6) MCP search returns incomplete results, (7) user mentions "Notion" in any capacity.
  Covers: MCP vs API decision matrix, when MCP fails, property update formats, content editing
  approaches, hybrid workflow pattern, bulk operation scripts, API setup. CRITICAL: MCP cannot
  list database items - this is a common failure mode. Always check this skill first.
author: Claude Code
tags: [notion, mcp, api, database, bulk-operations, tooling, required-skill]
user-invocable: false
---

# Notion Tooling Instructions

## Problem

Claude Code has Notion MCP tools exposed in context, leading to defaulting to MCP for all
Notion operations. However, MCP has significant gaps that require using the direct Notion
REST API instead. Knowing when to use which tool is critical for efficient Notion automation.

## Context / Trigger Conditions

Use this skill when:

- Working with Notion databases or pages
- Need to list/query all items in a database
- Performing bulk updates on multiple pages
- Deciding between MCP tools and direct API calls
- MCP search returns incomplete results
- Need to update page icons or cover images

## Core Decision Matrix

| Task                                  | Use API | Use MCP | Why                                                 |
| ------------------------------------- | ------- | ------- | --------------------------------------------------- |
| **List ALL database items**           | ✅      | ❌      | MCP cannot do this - only has semantic search       |
| **Filter by property values**         | ✅      | ❌      | API has `POST /databases/{id}/query` with filters   |
| **Bulk property updates (10+ pages)** | ✅      | ⚠️      | API is scriptable, faster for bulk                  |
| **Semantic/AI search**                | ❌      | ✅      | MCP has embedding-based search, API is keyword-only |
| **Targeted content edits**            | ⚠️      | ✅      | MCP uses snippet matching, API needs block IDs      |
| **Update icon/cover**                 | ✅      | ❌      | MCP doesn't expose this                             |
| **Create rich content**               | ⚠️      | ✅      | MCP uses markdown, API needs verbose JSON. Load `notion-style-matching` for formatting. |
| **Search within page content**        | ❌      | ✅      | API only searches titles                            |

## Solution: The Hybrid Approach

### First: Assess the Task

Before using any Notion tool, ask:

1. Do I need ALL items from a database? → **Use API**
2. Am I updating 5+ pages? → **Consider API script**
3. Do I need to find something by meaning/context? → **Use MCP search**
4. Am I editing specific text in page content? → **Use MCP**

### API for Database Queries

When you need all items or filtered lists, use the direct API:

```python
import json
import urllib.request

API_KEY = 'your-notion-api-key'  # Store in .env
DATABASE_ID = 'your-database-id'

headers = {
    'Authorization': f'Bearer {API_KEY}',
    'Notion-Version': '2022-06-28',
    'Content-Type': 'application/json'
}

# Query with filters
payload = {
    "filter": {
        "and": [
            {"property": "Status", "status": {"equals": "To Do"}},
            {"property": "Category", "select": {"does_not_equal": "Work"}}
        ]
    },
    "page_size": 100
}

url = f'https://api.notion.com/v1/databases/{DATABASE_ID}/query'
# ... pagination handling for has_more/next_cursor
```

### API for Property Updates

API uses nested JSON structure:

```python
# Update Category (select) and Deadline (date)
payload = {
    "properties": {
        "Category": {
            "select": {"name": "Health"}
        },
        "Deadline": {
            "date": {"start": "2026-02-14"}
        }
    }
}

url = f'https://api.notion.com/v1/pages/{PAGE_ID}'
# PATCH request
```

### MCP for Search and Content Edits

MCP is superior for:

**Semantic Search:**

```
mcp__notion__notion-search with query="things about mental wellness"
→ Finds "therapy", "breathing exercises" even without exact keywords
```

**Targeted Content Edits:**

```json
{
  "page_id": "...",
  "command": "replace_content_range",
  "selection_with_ellipsis": "old text...end of section",
  "new_str": "new replacement text"
}
```

**Note:** If inserting links to other Notion pages, load `notion-page-link-syntax` - the URL format
differs between read (`{{url}}`) and write (`url`), and `<page>` MOVES pages while `<mention-page>` links.

### MCP for Verification

After API updates, use MCP fetch to verify (per CLAUDE.md instruction):

```
mcp__notion__notion-fetch with id="page-id"
→ Returns formatted markdown with updated properties
```

## Property Format Comparison

| Property Type | API Format                                         | MCP Format                                |
| ------------- | -------------------------------------------------- | ----------------------------------------- |
| Select        | `{"select": {"name": "Value"}}`                    | `"PropertyName": "Value"`                 |
| Multi-select  | `{"multi_select": [{"name": "A"}, {"name": "B"}]}` | `"PropertyName": "[\"A\", \"B\"]"`        |
| Date          | `{"date": {"start": "2026-02-14"}}`                | `"date:PropertyName:start": "2026-02-14"` |
| Checkbox      | `{"checkbox": true}`                               | `"PropertyName": "__YES__"`               |
| Number        | `{"number": 42}`                                   | `"PropertyName": 42`                      |

## Content Editing Comparison

### API Approach (Complex)

1. `GET /blocks/{page_id}/children` → Get all blocks with IDs
2. Find target block by searching text content
3. Extract block ID and type
4. Reconstruct full `rich_text` array with edits
5. `PATCH /blocks/{block_id}` with preserved annotations

### MCP Approach (Simple)

1. Call `update-page` with `replace_content_range`
2. Provide start/end text snippet to match
3. Provide new text
4. Done - no block IDs needed

**WARNING:** If the page has child pages, load `notion-child-page-preservation` first - using
`replace_content` without preserving child page blocks will orphan or delete them.

## API Setup Requirements

1. Create Notion integration at https://www.notion.so/my-integrations
2. Get API key (starts with `ntn_` or `secret_`)
3. Share database/pages with the integration (Connections → Connect to)
4. Store API key securely (`.env` file, add to `.gitignore`)

## Verification

- API database query returns all expected items with pagination
- API property updates reflected when fetching page via MCP
- MCP search returns semantically relevant results
- MCP content edits preserve surrounding content
- After content updates, verify child pages still exist if they existed before (check for `<page>` blocks)

## Example: Bulk Task Organization

**Goal:** Update 67 tasks with categories and deadlines

**Approach:**

1. **API** - Query database for all To Do/Doing tasks (MCP can't list all)
2. **API** - Script to PATCH each page with Category and Deadline properties
3. **MCP** - Fetch sample pages to verify updates worked

```python
# Bulk update script pattern
for task in all_tasks:
    if task['needs_category'] or task['needs_deadline']:
        payload = {"properties": {}}
        if task['needs_category']:
            payload["properties"]["Category"] = {"select": {"name": assigned_category}}
        if task['needs_deadline']:
            payload["properties"]["Deadline"] = {"date": {"start": assigned_date}}

        # PATCH https://api.notion.com/v1/pages/{task['id']}
```

## Notes

- **Rate limits:** API allows ~3 requests/second (180/min). MCP has same limits.
- **Database sharing:** API integration must have database shared with it explicitly
- **MCP semantic search:** Works across workspace + connected apps (Slack, Drive, etc.)
- **API search:** Only matches page/database titles, not content
- **Block IDs:** API content edits need block IDs; these change if content is restructured

## Anti-Patterns

- ❌ Using MCP search repeatedly trying to find all database items
- ❌ Making 50+ individual MCP update calls when API script would be faster
- ❌ Using API block editing for simple text replacements
- ❌ Assuming MCP can do everything the API can
- ❌ Using `replace_content` on pages with child pages (see `notion-child-page-preservation`)
- ❌ Copying URL format from fetched content into write calls (see `notion-page-link-syntax`)

## References

- [Notion API Documentation](https://developers.notion.com/reference)
- [Notion MCP Supported Tools](https://developers.notion.com/docs/mcp-supported-tools)
- [Notion MCP Server GitHub - Issue #115](https://github.com/makenotion/notion-mcp-server/issues/115) - Database query gap
- [Notion MCP vs API Blog](https://www.notion.com/blog/notions-hosted-mcp-server-an-inside-look)
