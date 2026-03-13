#!/usr/bin/env python3
"""Register a hook command in a Claude Code settings.json file.

Usage: register_hook.py <settings_file> <event_type> <hook_command>

Idempotent — won't add duplicates. Creates the file if it doesn't exist.
"""

import json
import os
import sys


def main():
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <settings_file> <event_type> <hook_command>", file=sys.stderr)
        sys.exit(1)

    settings_file, event_type, hook_command = sys.argv[1], sys.argv[2], sys.argv[3]

    settings = {}
    if os.path.exists(settings_file):
        try:
            with open(settings_file) as f:
                settings = json.load(f)
        except (json.JSONDecodeError, ValueError):
            pass  # Treat empty/malformed file same as missing

    hooks = settings.setdefault("hooks", {})
    event_hooks = hooks.setdefault(event_type, [])

    # Check if already registered
    for group in event_hooks:
        for h in group.get("hooks", []):
            if h.get("command") == hook_command:
                return  # Already registered

    event_hooks.append({
        "matcher": "",
        "hooks": [{"type": "command", "command": hook_command}],
    })

    with open(settings_file, "w") as f:
        json.dump(settings, f, indent=4)
        f.write("\n")


if __name__ == "__main__":
    main()
