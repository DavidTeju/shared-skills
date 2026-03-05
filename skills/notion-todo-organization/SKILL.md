---
name: notion-todo-organization
description: |
  Organize Notion todo list database with categories and deadlines based on bandwidth constraints.
  Use when: (1) user asks to organize/categorize/schedule their todo list, plan their week,
  reschedule tasks, or says 'I missed some deadlines' or 'what should I work on', (2) multiple
  tasks need deadline assignment with load balancing, (3) tasks need category assignment based on
  content analysis, (4) tasks are past due and need rescheduling. Covers strategy selection
  (MCP vs API vs parallel subagents), deadline cascading when priorities change, past-due task
  triage, and bandwidth-aware scheduling.
author: Claude Code
tags: [notion, productivity, scheduling, todo, task-management]
---

# Notion Todo List Organization

## Problem

Organizing a Notion todo list database involves: querying all tasks, analyzing each for
appropriate categories, assigning deadlines that respect daily bandwidth constraints, and
handling updates when priorities shift. Different strategies work best depending on task count.

## Step 0: Discovery (ALWAYS RUN FIRST)

**MCP cannot list all database items** - you must query via API to know how many tasks need updates.

Run the discovery script to determine strategy:

```bash
python .claude/skills/notion-todo-organization/scripts/discover_tasks.py
```

Output includes:

- `total_needing_updates`: The key number for strategy selection
- `recommendation.strategy`: Which approach to use
- `tasks_preview`: First 10 tasks needing updates

**Example output:**

```json
{
  "summary": {
    "total_active_tasks": 67,
    "needs_category_only": 0,
    "needs_deadline_only": 52,
    "needs_both": 14,
    "total_needing_updates": 66
  },
  "recommendation": {
    "strategy": "parallel-subagents",
    "description": "Parallel subagents for analysis + bulk API updates"
  }
}
```

## Strategy Decision Matrix

| Task Count     | Strategy                    | Tools                         | Rationale                                   |
| -------------- | --------------------------- | ----------------------------- | ------------------------------------------- |
| **1-5 tasks**  | MCP-only                    | `notion-update-page`          | Low overhead, direct updates                |
| **6-20 tasks** | API query + MCP/API updates | Direct API + MCP verification | Efficient for moderate volume               |
| **20+ tasks**  | Parallel subagents + API    | 3 subagents + bulk API PATCH  | Maximizes throughput, parallelizes analysis |

### Strategy 1: MCP-Only (1-5 tasks)

```
1. Use notion-search or notion-fetch to get tasks
2. Analyze each task inline (no subagent needed)
3. Use notion-update-page with update_properties command
4. Verify each update
```

**When to use:** Quick updates, single task edits, immediate deadline changes.

### Strategy 2: API Query + Mixed Updates (6-20 tasks)

```python
# Query via API (MCP can't list all database items)
POST /databases/{id}/query with filters

# Update via API for speed
PATCH /pages/{id} with properties payload

# Verify via MCP
notion-fetch to confirm
```

**When to use:** Moderate task lists, weekly planning sessions, targeted batch updates.

### Strategy 3: Parallel Subagents + Bulk API (20+ tasks)

```
Phase 1: Query database via API (get all task IDs)
Phase 2: Split tasks across 3 parallel subagents for analysis
Phase 3: Coordinator assigns final deadlines from suggested ranges
Phase 4: Bulk update via API with rate limiting (0.35s delay)
Phase 5: Verify sample via MCP
```

**When to use:** Full todo list reorganization, onboarding new task system, major schedule overhaul.

## Bandwidth-Aware Scheduling

### Commute Time (Tue-Thu)

**35 minutes each way on the Connector** - quiet environment, no calls.

Good for commute:
- Texting, messaging, DMs
- Reading articles, docs, papers
- Small laptop tasks (reviewing PRs, writing notes, quick edits)
- Anything that fits in ~30 min chunks and doesn't require talking

Not for commute:
- Phone calls (scheduling, insurance, coordination)
- Video meetings
- Tasks requiring extended focus (>1 hour)

**Phone CALLS → schedule on Mon, Fri, or weekends.**

### Task-Day Matching

| Task Type             | Best Days      | Why                              |
| --------------------- | -------------- | -------------------------------- |
| Deep laptop work      | Mon, Fri       | Focused work blocks              |
| Phone CALLS           | Mon, Fri, Sat  | Can't call on Tue-Thu commute    |
| Quick tasks (<30 min) | Tue-Thu        | Fits commute window              |
| Reading/reviewing     | Tue-Thu        | Good commute activity            |
| Shopping/Errands      | Weekend        | Store hours, free time           |
| Explore/Backlog       | 2+ weeks out   | Low priority buffer              |

### Load Balancing (Model Reasoning)

The model assigns deadlines by reasoning through constraints - no script needed. Follow this logic:

1. **Sort tasks**: High importance first, then by deadline range start
2. **For each task**, pick a day within its deadline range that:
   - Matches task type to day type (laptop → Mon/Fri, phone → Tue-Thu)
   - Doesn't overload that day's capacity
   - Respects `depends_on` relationships
3. **Track running totals** mentally: "I've assigned ~2hrs to Friday already"
4. **If a day is full**, try next suitable day in range
5. **Fallback**: If no slot in range, use range end date

The model can also make judgment calls scripts can't:

- "These two tasks are related, schedule them same day"
- "This 'quick' task can squeeze into an already-full day"
- "User mentioned travel next week, avoid those dates"
- **Infer hard deadlines from content**: "Registration closes Feb 7" → must be before Feb 7
- **Distinguish soft vs hard**: "Consider therapy" has no real deadline; "File taxes" does

## Deadline Cascading

When a task slips or priority changes, cascade updates to maintain balance:

### Scenario: Task Moves Earlier

```
Original: Task A on Feb 5, Task B on Feb 5
Change: Task C (high priority) needs Feb 5

Cascade:
1. Identify Feb 5 capacity constraint
2. Find lowest-priority task (Task B) on Feb 5
3. Find next available slot for Task B (Feb 6)
4. If Feb 6 full, recursively cascade Feb 6 tasks
5. Update all affected tasks via API
```

### Scenario: Task Missed Deadline

```
Original: Task A deadline Jan 28 (missed)
Today: Jan 29

Cascade:
1. Query task's constraints (laptop? phone?)
2. Find next suitable day matching constraints
3. Check capacity - if full, bump lowest priority
4. Update task with new deadline
5. Log the slip for pattern analysis
```

### Cascade Logic (Model Reasoning)

When a high-priority task needs to move earlier, the model reasons through the ripple effects:

1. **Check target date capacity**: Can the task fit without bumping anything?
2. **If over capacity**: Find lowest-importance task on that date
3. **Compare importance**: Only bump if victim is lower priority than incoming task
4. **Recursively find new slot** for bumped task (repeat steps 1-3)
5. **Collect all updates**: Return list of all tasks that moved

**Example reasoning:**

> "Task C (high) needs Feb 5. Feb 5 has Task A (high) and Task B (low).
> I can bump Task B since it's lower priority. Feb 6 has capacity, so
> Task B moves to Feb 6. Final updates: Task C → Feb 5, Task B → Feb 6."

**Safety**: Don't cascade more than ~2 weeks out - if no slot found, flag for user review.

## Past-Due Task Handling

When tasks have deadlines in the past, use a **Triage + Smart Reschedule** approach.

### Step 1: Discover Past-Due Tasks

The discovery script includes past-due detection. Run it first:

```bash
python .claude/skills/notion-todo-organization/scripts/discover_tasks.py
```

Output now includes:

```json
{
  "summary": {
    "past_due_count": 5,
    "past_due_tasks": [
      {
        "id": "uuid",
        "title": "Task name",
        "deadline": "2026-01-28",
        "category": "Family",
        "days_overdue": 2
      }
    ]
  }
}
```

**Important:** The discovery script excludes Microsoft/work tasks (matching existing behavior).

### Step 2: Triage Each Task

Before blindly rescheduling, check if the task is still actionable:

**Fetch full task content** via `notion-fetch` and look for:

1. **Hard deadline indicators** in content:
   - "Registration closes...", "Due by...", "Deadline is...", "Expires on..."
   - "Before [event]", "Last day to...", specific event dates
   - If found → check if external deadline was missed

2. **Task status signals:**
   - "Waiting on X" → may be blocked, not just late
   - Event already passed → task may be moot
   - No content → likely a soft reminder, safe to reschedule

**Categorize each task:**

| Category | Criteria | Action |
|----------|----------|--------|
| **Still actionable** | No hard deadline missed, task still makes sense | Smart reschedule |
| **Missed window** | External deadline passed (registration closed, event happened) | Surface to user for decision |
| **No longer relevant** | Task is moot or someone else handled it | Suggest marking complete/cancelled |

### Step 3: Smart Reschedule (Actionable Tasks)

For tasks that are still actionable:

```
1. Check task constraints from Labels:
   - "Laptop" → schedule on Mon/Fri (focused work days)
   - "Phone" → schedule on Mon/Fri/Weekend (can't call on Tue-Thu commute)
   - "Quick" → can fit on any day

2. Factor in days overdue:
   - 1-2 days overdue → schedule within next 2-3 days
   - 3-7 days overdue → schedule within next week, prioritize higher
   - 7+ days overdue → evaluate if still relevant

3. Respect capacity:
   - Check how many tasks already scheduled on target day
   - If overloaded, try next suitable day

4. Apply hard deadline ceiling:
   - If task has external deadline (e.g., "registration closes Feb 7")
   - New deadline must be BEFORE that date
```

**Example triage reasoning:**

> "Register Angel for swim lessons" - 1 day overdue.
> Content shows: "Registration Window: Jan 20 - Feb 7"
> Hard deadline: Feb 7 (still open)
> Classes start: Feb 2
> Labels: Laptop
> → Still actionable. Schedule for Feb 1 (Sat) - before classes start, registration still open.

> "Send dad dates for Seattle visit" - 1 day overdue.
> Content: empty
> Labels: Phone, Quick
> → No hard deadline, soft reminder. Schedule for Jan 31 (Fri) - good day for phone tasks.

### Step 4: Handle "Missed Window" Tasks

For tasks where external deadlines were missed:

1. **Don't auto-reschedule** - the action needed may be different
2. **Surface to user** with context:
   - What deadline was missed
   - What alternatives exist (e.g., next session, different provider)
3. **User decides:** reschedule anyway, mark done, or take different action

### Combined Workflow

```
User: "What's overdue?" or "I missed some deadlines"

1. Run discovery script → get past_due_tasks list
2. For each past-due task:
   a. Fetch full content via notion-fetch
   b. Scan for hard deadline indicators
   c. Categorize: actionable / missed window / moot
3. Present flagged "missed window" tasks to user first
4. Smart reschedule the "actionable" tasks
5. Update via MCP (small count) or API (bulk)
6. Verify updates
```

## Subagent Analysis Schema

When using parallel subagents, each returns:

```json
{
  "page_id": "uuid",
  "title": "Task name",
  "category": "Health", // or null if already has one
  "estimated_minutes": 45, // integer, used for capacity math
  "importance": "high", // "high" | "medium" | "low"
  "urgency_notes": "Registration closes Feb 7",
  "deadline_range": ["2026-02-01", "2026-02-03"], // 2-3 day window
  "rationale": "Brief explanation of category/deadline choice",
  "constraints": {
    "requires_laptop": true,
    "phone_friendly": false,
    "time_sensitive": true, // affects deadline flexibility
    "has_hard_deadline": false, // true = external deadline exists
    "depends_on": null // page_id of blocking task, if any
  }
}
```

**Field notes:**

- `estimated_minutes`: Integer for capacity math (daily budget is in minutes)
- `importance`: Enum for clear prioritization - "high" (do this week), "medium" (do within 2 weeks), "low" (backlog)
- `deadline_range`: Subagent suggests a window; coordinator picks exact date based on load
- `depends_on`: Enables task chaining (e.g., "buy supplies" before "start project")
- `has_hard_deadline`: **Inferred from task content** - look for:
  - "Registration closes...", "Due by...", "Deadline is...", "Expires on..."
  - "Before [event]", "Last day to...", event dates (concerts, appointments)
  - When true, `deadline_range[1]` is a **ceiling**, not a suggestion - never schedule after

## Verification

After bulk updates:

1. Use `mcp__notion__notion-fetch` on 2-3 sample tasks
2. Confirm properties match expected values
3. Log any discrepancies for retry

## Example: Weekly Planning Session (15 tasks)

```
User: "Help me plan my week"

Strategy: API query + API updates (Strategy 2)

1. Query database for "To Do" status tasks
2. Inline analysis (no subagents for 15 tasks)
3. Build schedule considering:
   - Today's day of week
   - Upcoming deadlines
   - Task labels (Laptop, Phone, Quick)
4. Update via API batch
5. Verify via MCP fetch
6. Present schedule to user
```

## Example: Full Reorganization (60+ tasks)

```
User: "Organize my entire todo list"

Strategy: Parallel subagents + bulk API (Strategy 3)

1. API query all tasks (pagination if >100)
2. Filter out completed/archived
3. Split into 3 groups (~20 each)
4. Launch 3 parallel subagents for analysis
5. Collect results, assign final deadlines
6. Bulk API update with 0.35s rate limiting
7. Verify samples via MCP
8. Generate summary report
```

## Notes

- **Rate Limiting**: Notion API allows ~3 requests/second. Use 0.35s delay for bulk operations.
- **MCP Limitation**: Cannot list all database items—only semantic search. Use API for full queries.
- **Category Creation**: If a new category is needed, it's auto-created on first use via select property.
- **Timezone**: Deadline dates are date-only (no time). Notion handles timezone display.

## Related Skills

- `querying-and-updating-notion`: **Load this first** for MCP vs API decisions. This skill builds on top of those fundamentals.
- `notion-style-matching`: Format content to match user preferences

## References

- [Notion API: Query Database](https://developers.notion.com/reference/post-database-query)
- [Notion API: Update Page Properties](https://developers.notion.com/reference/patch-page)
- Notion MCP Server documentation
