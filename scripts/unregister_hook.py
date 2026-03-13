#!/usr/bin/env python3
"""Remove a hook command from a Claude Code settings.json file.

Usage: unregister_hook.py <settings_file> <hook_command>

Removes the hook command from all event types. Cleans up empty groups/keys.
No-op if the file doesn't exist or the hook isn't found.
"""

import json
import os
import sys


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <settings_file> <hook_command>", file=sys.stderr)
        sys.exit(1)

    settings_file, hook_command = sys.argv[1], sys.argv[2]

    if not os.path.exists(settings_file):
        return

    try:
        with open(settings_file) as f:
            settings = json.load(f)
    except (json.JSONDecodeError, ValueError):
        return  # Can't parse — leave file alone

    changed = False
    for event_type in list(settings.get("hooks", {}).keys()):
        groups = settings["hooks"][event_type]
        new_groups = []
        for group in groups:
            new_hooks = [h for h in group.get("hooks", []) if h.get("command") != hook_command]
            if new_hooks:
                group["hooks"] = new_hooks
                new_groups.append(group)
            elif group.get("hooks"):
                changed = True  # Had hooks but they were all removed
            else:
                new_groups.append(group)  # Empty hooks list, keep as-is

        if len(new_groups) != len(groups):
            changed = True
        settings["hooks"][event_type] = new_groups

        # Remove empty event types
        if not settings["hooks"][event_type]:
            del settings["hooks"][event_type]
            changed = True

    # Remove empty hooks key
    if not settings.get("hooks"):
        settings.pop("hooks", None)
        changed = True

    if changed:
        with open(settings_file, "w") as f:
            json.dump(settings, f, indent=4)
            f.write("\n")


if __name__ == "__main__":
    main()
