# Subagent Analysis Schema

> **Load this when:** Using Strategy 3 (parallel subagents) for 20+ tasks.

When using parallel subagents for task analysis, each subagent returns this JSON schema:

```json
{
  "page_id": "uuid",
  "title": "Task name",
  "category": "Health",
  "estimated_minutes": 45,
  "importance": "high",
  "urgency_notes": "Registration closes Feb 7",
  "deadline_range": ["2026-02-01", "2026-02-03"],
  "rationale": "Brief explanation of category/deadline choice",
  "constraints": {
    "requires_laptop": true,
    "phone_friendly": false,
    "time_sensitive": true,
    "has_hard_deadline": false,
    "depends_on": null
  }
}
```

## Field Definitions

| Field | Type | Description |
|-------|------|-------------|
| `page_id` | string | Notion page UUID |
| `title` | string | Task name (for logging) |
| `category` | string\|null | Suggested category, or null if already has one |
| `estimated_minutes` | integer | For capacity math (daily budget is in minutes) |
| `importance` | enum | `"high"` (this week), `"medium"` (within 2 weeks), `"low"` (backlog) |
| `urgency_notes` | string | Any time-sensitive info found in content |
| `deadline_range` | [string, string] | 2-3 day window; coordinator picks exact date based on load |
| `rationale` | string | Brief explanation for debugging |
| `constraints.requires_laptop` | boolean | Needs focused laptop time |
| `constraints.phone_friendly` | boolean | Can be done via phone/text |
| `constraints.time_sensitive` | boolean | Affects deadline flexibility |
| `constraints.has_hard_deadline` | boolean | External deadline exists (inferred from content) |
| `constraints.depends_on` | string\|null | page_id of blocking task |

## Hard Deadline Detection

Set `has_hard_deadline: true` when task content contains:
- "Registration closes...", "Due by...", "Deadline is...", "Expires on..."
- "Before [event]", "Last day to...", specific event dates

When true, `deadline_range[1]` is a **ceiling** - never schedule after it.
