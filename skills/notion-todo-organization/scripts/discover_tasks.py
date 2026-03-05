#!/usr/bin/env python3
"""
Notion Todo List Discovery Script

Queries the todo list database and returns counts of tasks needing updates,
including past-due tasks that need rescheduling.

Use this FIRST to determine which organization strategy to use.

Usage:
    python discover_tasks.py

Requires:
    - NOTION_API_KEY environment variable or .env file
    - Database ID configured below or passed as argument

Output:
    JSON with task counts, past-due tasks, and strategy recommendation
"""

import json
import urllib.request
import urllib.error
import os
import sys
from pathlib import Path
from datetime import datetime

# Configuration
DATABASE_ID = "12321fb796a04ba58a114f9bd91a03d3"  # David's Todo List

def load_api_key():
    """Load API key from environment or .env file."""
    api_key = os.environ.get("NOTION_API_KEY")
    if api_key:
        return api_key

    # Try common .env locations
    env_paths = [
        Path.cwd() / ".env",
        Path.home() / "projects/personal_assistant_claude/.env",
    ]

    for env_path in env_paths:
        if env_path.exists():
            with open(env_path) as f:
                for line in f:
                    if line.startswith("NOTION_API_KEY="):
                        return line.strip().split("=", 1)[1]

    raise ValueError("NOTION_API_KEY not found in environment or .env file")

def query_database(api_key, database_id, filters=None):
    """Query Notion database with pagination."""
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Notion-Version": "2022-06-28",
        "Content-Type": "application/json"
    }

    payload = {"page_size": 100}
    if filters:
        payload["filter"] = filters

    url = f"https://api.notion.com/v1/databases/{database_id}/query"
    all_results = []
    has_more = True
    next_cursor = None

    while has_more:
        if next_cursor:
            payload["start_cursor"] = next_cursor

        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(url, data=data, headers=headers, method="POST")

        try:
            with urllib.request.urlopen(req) as response:
                result = json.loads(response.read().decode("utf-8"))
                all_results.extend(result.get("results", []))
                has_more = result.get("has_more", False)
                next_cursor = result.get("next_cursor")
        except urllib.error.HTTPError as e:
            error_body = e.read().decode("utf-8")
            raise Exception(f"API Error {e.code}: {error_body}")

    return all_results

def analyze_tasks(tasks):
    """Analyze tasks and return counts, including past-due detection."""
    today = datetime.now().strftime("%Y-%m-%d")

    results = {
        "total": len(tasks),
        "needs_category": 0,
        "needs_deadline": 0,
        "needs_both": 0,
        "complete": 0,
        "past_due": 0,
        "by_status": {},
        "by_category": {},
        "tasks_needing_updates": [],
        "past_due_tasks": []
    }

    for task in tasks:
        props = task.get("properties", {})

        # Get status
        status = props.get("Status", {}).get("status", {}).get("name", "Unknown")
        results["by_status"][status] = results["by_status"].get(status, 0) + 1

        # Skip non-active tasks
        if status not in ["To Do", "Doing"]:
            continue

        # Get title
        title_prop = props.get("Name", {}).get("title", [])
        title = title_prop[0].get("plain_text", "") if title_prop else ""

        # Get category
        category = props.get("Category", {}).get("select")
        category_name = category.get("name") if category else None

        # Get deadline
        deadline = props.get("Deadline", {}).get("date")
        deadline_date = deadline.get("start") if deadline else None

        # Track category distribution
        cat_key = category_name or "Uncategorized"
        results["by_category"][cat_key] = results["by_category"].get(cat_key, 0) + 1

        # Check if past due (excluding Microsoft/work tasks)
        is_past_due = False
        if deadline_date and deadline_date < today and category_name != "Microsoft":
            is_past_due = True
            results["past_due"] += 1
            days_overdue = (datetime.now() - datetime.strptime(deadline_date, "%Y-%m-%d")).days
            results["past_due_tasks"].append({
                "id": task["id"],
                "title": title[:60],
                "deadline": deadline_date,
                "category": category_name,
                "days_overdue": days_overdue
            })

        # Determine what's needed
        needs_cat = category_name is None
        needs_deadline = deadline_date is None

        if needs_cat and needs_deadline:
            results["needs_both"] += 1
        elif needs_cat:
            results["needs_category"] += 1
        elif needs_deadline:
            results["needs_deadline"] += 1
        else:
            results["complete"] += 1

        # Track tasks needing updates (category or deadline missing)
        if needs_cat or needs_deadline:
            results["tasks_needing_updates"].append({
                "id": task["id"],
                "title": title[:60],
                "needs_category": needs_cat,
                "needs_deadline": needs_deadline,
                "current_category": category_name,
                "current_deadline": deadline_date
            })

    # Sort past-due tasks by days overdue (most overdue first)
    results["past_due_tasks"].sort(key=lambda x: x["days_overdue"], reverse=True)

    return results

def recommend_strategy(analysis):
    """Recommend organization strategy based on task counts."""
    total_needing_updates = (
        analysis["needs_category"] +
        analysis["needs_deadline"] +
        analysis["needs_both"]
    )

    if total_needing_updates == 0:
        return {
            "strategy": "none",
            "description": "All tasks already have categories and deadlines",
            "action": "No updates needed"
        }
    elif total_needing_updates <= 5:
        return {
            "strategy": "mcp-only",
            "description": "Use MCP notion-update-page directly",
            "action": "Analyze inline, update via MCP, verify each",
            "estimated_time": "2-3 minutes"
        }
    elif total_needing_updates <= 20:
        return {
            "strategy": "api-mixed",
            "description": "Use API for query/updates, MCP for verification",
            "action": "Inline analysis, batch API updates, sample verification",
            "estimated_time": "5-10 minutes"
        }
    else:
        return {
            "strategy": "parallel-subagents",
            "description": "Parallel subagents for analysis + bulk API updates",
            "action": "Split into 3 groups, parallel analysis, coordinated deadlines, bulk update",
            "estimated_time": "15-30 minutes"
        }

def main():
    try:
        api_key = load_api_key()
    except ValueError as e:
        print(json.dumps({"error": str(e)}), file=sys.stderr)
        sys.exit(1)

    # Query for To Do and Doing tasks (excluding Microsoft/work)
    filters = {
        "and": [
            {
                "or": [
                    {"property": "Status", "status": {"equals": "To Do"}},
                    {"property": "Status", "status": {"equals": "Doing"}}
                ]
            },
            {
                "or": [
                    {"property": "Category", "select": {"is_empty": True}},
                    {"property": "Category", "select": {"does_not_equal": "Microsoft"}}
                ]
            }
        ]
    }

    try:
        tasks = query_database(api_key, DATABASE_ID, filters)
    except Exception as e:
        print(json.dumps({"error": str(e)}), file=sys.stderr)
        sys.exit(1)

    analysis = analyze_tasks(tasks)
    recommendation = recommend_strategy(analysis)

    output = {
        "summary": {
            "total_active_tasks": analysis["total"],
            "needs_category_only": analysis["needs_category"],
            "needs_deadline_only": analysis["needs_deadline"],
            "needs_both": analysis["needs_both"],
            "already_complete": analysis["complete"],
            "total_needing_updates": (
                analysis["needs_category"] +
                analysis["needs_deadline"] +
                analysis["needs_both"]
            ),
            "past_due_count": analysis["past_due"]
        },
        "recommendation": recommendation,
        "category_distribution": analysis["by_category"],
        "status_distribution": analysis["by_status"],
        "tasks_preview": analysis["tasks_needing_updates"][:10],  # First 10 for preview
        "past_due_tasks": analysis["past_due_tasks"]  # All past-due tasks (excluding Microsoft)
    }

    print(json.dumps(output, indent=2))

if __name__ == "__main__":
    main()
