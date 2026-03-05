---
name: notion-child-page-preservation
description: |
  Prevent accidental deletion of Notion child pages when updating parent page content.
  Use when: (1) using replace_content command on a Notion page that has subpages,
  (2) updating page content where child pages exist as blocks, (3) seeing "deleted"
  status on pages after parent content update. In Notion, child pages exist as blocks
  within parent content - replacing all content removes the child page blocks and
  orphans or deletes the child pages.
author: Claude Code
user-invocable: false
---

# Notion Child Page Preservation

## Problem
When using `replace_content` on a Notion page, child pages can be accidentally deleted
or orphaned because child pages exist as blocks within the parent page's content, not
as separate linked entities.

## Context / Trigger Conditions
- Using the `notion-update-page` tool with `command: "replace_content"`
- Parent page has child/subpages
- Content in the response shows `<page url="...">Child Page Name</page>` blocks
- After update, child pages show as deleted or are no longer accessible from parent

## Solution

### Before updating a page with children:
1. **Fetch the page first** to identify any child page blocks in the content
2. **Look for `<page url="...">` tags** in the content - these are child pages
3. **Use `replace_content_range` instead of `replace_content`** to preserve child page blocks
4. **If you must replace all content**, re-include the child page blocks in your new content

### Safe update patterns:

**Pattern 1: Use range replacement**
```json
{
  "command": "replace_content_range",
  "selection_with_ellipsis": "Old content...to replace",
  "new_str": "New content here"
}
```

**Pattern 2: Preserve child page blocks**
If replacing all content, include the child page references:
```
Your new content here

<page url="{{https://www.notion.so/child-page-id}}">Child Page Name</page>
```

**Pattern 3: Insert content after/before child pages**
Use `insert_content_after` to add content without disturbing page blocks.

## Verification
After any content update:
1. Fetch the parent page again
2. Verify child page blocks still appear in content
3. Fetch child pages to confirm they still have correct parent in ancestor-path

## Example

**Before (dangerous):**
```json
{
  "page_id": "parent-id",
  "command": "replace_content",
  "new_str": "Completely new content"
}
```
This removes all child page blocks.

**After (safe):**
```json
{
  "page_id": "parent-id",
  "command": "replace_content_range",
  "selection_with_ellipsis": "# Old Header...end of section",
  "new_str": "# New Header\nNew section content"
}
```
This preserves child page blocks outside the replacement range.

## Notes
- Child pages in Notion are NOT like file system directories - they're blocks embedded in content
- Hyperlinks to pages (`[text](url)`) are different from page blocks - links don't establish parent-child relationships
- Always read the page content after updates to verify child pages weren't affected
- If a child page is orphaned, it may still exist but be inaccessible from the parent's navigation
