---
name: browser-tab-resource-investigation
description: |
  Programmatically identify and manage resource-heavy browser tabs on macOS using ps, AppleScript,
  and forensic techniques. Use when user says: (1) "my browser is using a lot of CPU/memory",
  (2) "which tab is causing my Mac to run slow/hot", (3) "Edge/Chrome/Safari is hogging resources",
  (4) "find the runaway tab", (5) "there's a tab making my computer slow", (6) "close duplicate tabs",
  (7) "clean up my browser tabs". Covers process investigation, AppleScript tab enumeration,
  forensic identification (kill → observe → identify), and bulk tab operations.
author: Claude Code
user-invocable: false
---

# Browser Tab Resource Investigation (Programmatic)

## Problem
When a browser is consuming excessive CPU or memory, you need to programmatically identify
which specific tab is the culprit and potentially perform bulk tab cleanup. Browser renderer
processes show as generic entries (e.g., "Microsoft Edge Helper (Renderer)") in Activity
Monitor, with no indication of which tab they're rendering.

## Programmatic Investigation Workflow

### Step 1: Identify High-Resource Browser Processes

```bash
# Top CPU consumers
ps aux | sort -nrk 3,3 | head -n 15

# Top memory consumers
ps aux | sort -nrk 4,4 | head -n 15
```

**Look for:**
- Browser renderer processes (Edge Helper, Chrome Helper, etc.)
- High CPU: >100% (using multiple cores) or sustained >50%
- High memory: >500MB for a single renderer, >1GB is excessive
- Note the PID of suspicious processes

**Common patterns:**
```
user  77725 337.5 12.8 1865673216 3254208  ??  Microsoft Edge Helper (Renderer)
                ^^^^  ^^^^
                CPU%  MEM%
```

### Step 2: Enumerate All Browser Tabs

**For Microsoft Edge:**
```bash
osascript << 'EOF'
tell application "Microsoft Edge"
    set tabData to {}
    repeat with w in windows
        repeat with t in tabs of w
            try
                set tabURL to URL of t
                set tabTitle to title of t
                set end of tabData to tabURL & " ||| " & tabTitle
            end try
        end repeat
    end repeat

    set AppleScript's text item delimiters to linefeed
    return tabData as string
end tell
EOF
```

**For Chrome (same pattern):**
```bash
# Replace "Microsoft Edge" with "Google Chrome"
```

**For Safari:**
```bash
osascript << 'EOF'
tell application "Safari"
    set tabData to {}
    repeat with w in windows
        repeat with t in tabs of w
            try
                set tabURL to URL of t
                set tabTitle to name of t
                set end of tabData to tabURL & " ||| " & tabTitle
            end try
        end repeat
    end repeat

    set AppleScript's text item delimiters to linefeed
    return tabData as string
end tell
EOF
```

### Step 3: Forensic Identification

**The Kill-and-Observe Technique:**

When you can't directly map a PID to a specific tab, use this forensic approach:

1. Kill the high-resource process
2. Immediately check which tabs are now missing/crashed
3. The disappeared tab was the culprit

```bash
# Kill the process
kill -9 [PID]

# Re-enumerate tabs to see what's missing
# (run the AppleScript from Step 2 again)
```

**Key insight:** The tab that disappears after killing the renderer process was being
rendered by that process. This works because modern browsers isolate tabs into separate
renderer processes for security and stability.

### Step 4: Bulk Tab Operations

**Close tabs by URL pattern:**
```bash
osascript << 'EOF'
tell application "Microsoft Edge"
    set closedCount to 0
    repeat with w in windows
        set tabList to tabs of w
        repeat with i from (count of tabList) to 1 by -1
            set t to item i of tabList
            try
                if URL of t contains "problematic-site.com" then
                    close t
                    set closedCount to closedCount + 1
                end if
            end try
        end repeat
    end repeat
    return "Closed " & closedCount & " tabs"
end tell
EOF
```

**Important:** Iterate backwards (`to 1 by -1`) when closing tabs to avoid index issues
as tabs are removed from the list.

**Close duplicate tabs:**
```bash
osascript << 'EOF'
tell application "Microsoft Edge"
    set seenURLs to {}
    set closedCount to 0
    repeat with w in windows
        set tabList to tabs of w
        repeat with i from (count of tabList) to 1 by -1
            set t to item i of tabList
            try
                set tabURL to URL of t
                if seenURLs contains tabURL then
                    close t
                    set closedCount to closedCount + 1
                else
                    set end of seenURLs to tabURL
                end if
            end try
        end repeat
    end repeat
    return "Closed " & closedCount & " duplicate tabs"
end tell
EOF
```

### Step 5: Extract URLs from Redirect Services

**Problem:** Services like ClearSpace use redirect URLs with encoded `returnUrl` parameters:
```
https://app.getclearspace.com/breathe?returnUrl=https%3A%2F%2Fwww.reddit.com%2F...
```

**Solution:** Decode and navigate to the real URL:

```bash
osascript << 'EOF'
tell application "Microsoft Edge"
    set processedCount to 0
    set redirectTabs to {}

    -- Collect redirect tabs (e.g., clearspace, short.io, etc.)
    repeat with w in windows
        repeat with t in tabs of w
            try
                set tabURL to URL of t
                if tabURL contains "getclearspace.com" and tabURL contains "returnUrl=" then
                    set end of redirectTabs to {tabRef:t, url:tabURL}
                end if
            end try
        end repeat
    end repeat

    -- Process each redirect tab
    repeat with rdTab in redirectTabs
        set tabURL to url of rdTab
        set tabRef to tabRef of rdTab

        if tabURL contains "returnUrl=" then
            set AppleScript's text item delimiters to "returnUrl="
            set urlParts to text items of tabURL
            if (count of urlParts) > 1 then
                set encodedURL to item 2 of urlParts

                -- Decode common URL encoding
                set decodedURL to encodedURL
                set decodedURL to my replaceText(decodedURL, "%3A", ":")
                set decodedURL to my replaceText(decodedURL, "%2F", "/")
                set decodedURL to my replaceText(decodedURL, "%3F", "?")
                set decodedURL to my replaceText(decodedURL, "%3D", "=")
                set decodedURL to my replaceText(decodedURL, "%26", "&")

                -- Remove trailing parameters
                if decodedURL contains "&" then
                    set AppleScript's text item delimiters to "&"
                    set decodedURL to text item 1 of (text items of decodedURL)
                end if

                set AppleScript's text item delimiters to ""

                -- Navigate to decoded URL
                set URL of tabRef to decodedURL
                set processedCount to processedCount + 1
            end if
        end if
    end repeat

    return "Converted " & processedCount & " redirect tabs"
end tell

on replaceText(theText, oldString, newString)
    set AppleScript's text item delimiters to oldString
    set textItems to text items of theText
    set AppleScript's text item delimiters to newString
    set theText to textItems as string
    set AppleScript's text item delimiters to ""
    return theText
end replaceText
EOF
```

## Common Resource-Heavy Tab Patterns

Based on investigation, these are frequent culprits:

**High CPU (>100%):**
- AI chat interfaces (Claude, ChatGPT, Gemini) with long conversation history
- Notion pages (especially with many blocks or live databases)
- Google Sheets with complex formulas or large datasets
- Web-based IDEs (CodeSandbox, Replit, StackBlitz)
- Sites with poorly optimized animations or infinite loops

**High Memory (>1GB):**
- Single-page apps (SPAs) with memory leaks
- Pages with many loaded images/videos
- Multiple tabs from the same site (accumulating shared resources)
- WebSocket connections accumulating data

## Verification

After identifying and closing problematic tabs:

```bash
# Check if resources have been freed
ps aux | grep -i "edge\|chrome\|safari" | grep -v grep | sort -nrk 3,3 | head -5
```

CPU and memory usage should drop significantly for browser processes.

## Analysis Workflow for User Requests

When a user reports browser performance issues:

1. **Run ps aux** to identify high-resource processes
2. **Enumerate tabs** with AppleScript to build a complete picture
3. **Analyze URLs** for patterns (many tabs from same site, known heavy sites)
4. **If unclear, use forensic technique**: Kill suspicious PID, observe what disappears
5. **Suggest bulk operations**: Close duplicates, old tabs, redirect conversions
6. **Report findings**: "The Notion tab was using 3.2GB and 337% CPU"

## Notes

- Browser renderer processes are sandboxed per-tab (Chrome/Edge) or per-group (Safari)
- Killing a renderer only affects that specific tab, not the whole browser
- Some tabs share resources (same origin), so closing one may not fully free memory
- AppleScript may fail if browser is unresponsive - kill process first, then enumerate
- Always iterate backwards when closing tabs to avoid index shifting issues
- URL decoding is straightforward: `%XX` → character, but watch for edge cases

## Limitations

- Cannot directly see real-time CPU/memory per-tab programmatically (would need browser's
  internal task manager API)
- AppleScript can be slow with 100+ tabs
- Safari's AppleScript support is less granular than Chrome/Edge
- Cannot interact with browser extensions programmatically

## Alternative: Suggest Built-in Tools

When appropriate, remind users they can also use:
- **Edge/Chrome**: Press `Shift+Esc` to open built-in Browser Task Manager
- **Safari**: Activity Monitor → search "safari" → see per-tab processes

But for bulk operations, scripted cleanup, or when user wants automated help, use the
programmatic approaches in this skill.

## References

- [How to Use Microsoft Edge Task Manager](https://www.microsoft.com/en-us/edge/learning-center/how-to-use-edge-task-manager)
- [How to Fix High CPU Usage by Chrome Helper Renderer on macOS](https://myspybot.com/google-chrome-helper-renderer-high-cpu-usage-macos/)
