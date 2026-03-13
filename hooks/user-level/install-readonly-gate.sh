#!/usr/bin/env bash
# Install the readonly-gate hook for Claude Code.
#
# Copies readonly-gate.sh to ~/.claude/hooks/ and registers it as a
# PreToolUse hook in ~/.claude/settings.json. Idempotent — safe to re-run.
#
# Usage:
#   bash install-readonly-gate.sh            # install
#   bash install-readonly-gate.sh --dry-run  # preview changes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_SRC="$SCRIPT_DIR/readonly-gate.sh"
HOOK_DIR="$HOME/.claude/hooks"
HOOK_DST="$HOOK_DIR/readonly-gate.sh"
SETTINGS="$HOME/.claude/settings.json"
EVENT_TYPE="PreToolUse"
HOOK_CMD="~/.claude/hooks/readonly-gate.sh"
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    -h|--help)
      echo "Usage: $0 [--dry-run]"
      echo "Install the readonly-gate hook for Claude Code."
      exit 0
      ;;
  esac
done

if [[ ! -f "$HOOK_SRC" ]]; then
  echo "ERROR: readonly-gate.sh not found at $HOOK_SRC"
  echo "Run this script from the hooks/user-level/ directory."
  exit 1
fi

# ── Step 1: Copy hook to ~/.claude/hooks/ ──
echo "Hook: $HOOK_SRC → $HOOK_DST"
if [[ -L "$HOOK_DST" ]] && [[ "$(readlink "$HOOK_DST")" == "$HOOK_SRC" || "$(readlink -f "$HOOK_DST")" == "$HOOK_SRC" ]]; then
  echo "  Already symlinked (managed by setup.sh)"
elif $DRY_RUN; then
  echo "  WOULD COPY"
else
  mkdir -p "$HOOK_DIR"
  # Remove stale file (but not symlinks to this source — handled above)
  [[ -e "$HOOK_DST" || -L "$HOOK_DST" ]] && rm -f "$HOOK_DST"
  cp "$HOOK_SRC" "$HOOK_DST"
  chmod +x "$HOOK_DST"
  echo "  ✓ Copied"
fi

# ── Step 2: Register in settings.json ──
echo "Settings: $SETTINGS"
if $DRY_RUN; then
  echo "  WOULD REGISTER $EVENT_TYPE → $HOOK_CMD"
else
  # Inline registration — no external dependencies.
  python3 -c "
import json, os, sys

settings_file = '$SETTINGS'
event_type = '$EVENT_TYPE'
hook_command = '$HOOK_CMD'

settings = {}
if os.path.exists(settings_file):
    try:
        with open(settings_file) as f:
            settings = json.load(f)
    except (json.JSONDecodeError, ValueError):
        pass

hooks = settings.setdefault('hooks', {})
event_hooks = hooks.setdefault(event_type, [])

for group in event_hooks:
    for h in group.get('hooks', []):
        if h.get('command') == hook_command:
            print('  Already registered')
            sys.exit(0)

event_hooks.append({
    'matcher': '',
    'hooks': [{'type': 'command', 'command': hook_command}],
})

os.makedirs(os.path.dirname(settings_file), exist_ok=True)
with open(settings_file, 'w') as f:
    json.dump(settings, f, indent=4)
    f.write('\n')

print('  ✓ Registered')
"
fi

echo ""
echo "Done. The readonly-gate hook will auto-approve read-only tool calls"
echo "in all future Claude Code sessions."
