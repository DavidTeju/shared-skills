# Deadline Cascading Reference

> **Load this when:** Scheduling conflicts occur, tasks need to bump other tasks, or priorities change mid-schedule.

When a task slips or priority changes, cascade updates to maintain balance:

## Scenario: Task Moves Earlier

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

## Scenario: Task Missed Deadline

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

## Cascade Logic (Model Reasoning)

When a high-priority task needs to move earlier, reason through the ripple effects:

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
