#!/bin/bash
# readonly-gate.sh — Auto-approve read-only tool calls, bubble writes to user.
#
# Read-only operations (file reads, searches, web fetches) are auto-approved.
# Write operations (edits, bash commands that modify state) require user approval.
# Bash commands get smart classification: read-only commands pass, writes get gated.
# Tests: .claude/hooks/test_readonly_gate.sh

set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# ─── Read-only tool allowlists ───────────────────────────────────────────────

READONLY_CORE="^(Read|Glob|Grep|WebSearch|WebFetch|TaskOutput|TaskList|TaskGet|ListMcpResourcesTool|ReadMcpResourceTool|AskUserQuestion)$"

READONLY_NOTION="^mcp__notion__notion-(fetch|search|get-comments|get-teams|get-users)$"

# Beeper MCP removed — replaced by beeper-desktop-cli (see beeper skill)

READONLY_BROWSER="^mcp__playwright__browser_(snapshot|take_screenshot|console_messages|network_requests)$"

READONLY_SERENA="^mcp__plugin_serena_serena__(read_file|list_dir|find_file|search_for_pattern|get_symbols_overview|find_symbol|find_referencing_symbols|read_memory|list_memories|check_onboarding_performed|get_current_config|initial_instructions)$"

READONLY_C7="^mcp__context7__(resolve-library-id|query-docs)$"

# Task/Agent spawning is allowed — individual subagent tools are gated by this same hook
SPAWNING="^(Task|TaskCreate|TaskUpdate)$"

# ─── Classification ──────────────────────────────────────────────────────────

approve() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# For write ops: exit silently (no output) → defers to normal permission system,
# which respects bypass/acceptEdits mode. Only use deny() for truly dangerous ops.

# Check read-only tools
for pattern in "$READONLY_CORE" "$READONLY_NOTION" "$READONLY_BROWSER" "$READONLY_SERENA" "$READONLY_C7" "$SPAWNING"; do
  if echo "$TOOL_NAME" | grep -qE "$pattern"; then
    approve "Read-only: auto-approved"
  fi
done

# browser_tabs needs input-level inspection — "list" is read-only, others are writes
if [ "$TOOL_NAME" = "mcp__playwright__browser_tabs" ]; then
  ACTION=$(echo "$INPUT" | jq -r '.tool_input.action // empty')
  if [ "$ACTION" = "list" ]; then
    approve "Read-only: browser_tabs list"
  else
    exit 0  # Defer to permission system
  fi
fi

# ─── Bash command classification ─────────────────────────────────────────────

if [ "$TOOL_NAME" = "Bash" ]; then
  COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

  # Dangerous patterns anywhere in the command → ask user
  WRITE_PATTERNS='(^|\s|;|&&|\||\()(rm|mv|cp|mkdir|rmdir|chmod|chown|chgrp|ln|touch|truncate)\s'
  GIT_WRITE='git\s+(push|commit|reset|rebase|merge|checkout|stash|cherry-pick|tag|branch\s+-[dD])'
  REDIRECT='(>>|>\||>[^&>])'
  PKG_WRITE='(npm|yarn|pnpm|pip|brew)\s+(install|uninstall|remove|add|upgrade|update|link)'
  DOCKER_WRITE='docker\s+(rm|rmi|stop|kill|build|push|run|exec|compose)'
  CURL_WRITE='curl\s+.+(-X\s+(POST|PUT|PATCH|DELETE)|--data|-d\s)'
  SED_WRITE='sed\s+(-[a-zA-Z]*i|-i)'

  BACKTICK='`'  # backtick subshells can hide arbitrary commands

  # Strip safe stderr redirects before checking for write-redirects
  # (2>/dev/null, 2>&1, 2>>/dev/null are read-only — just stderr suppression/merge)
  COMMAND_FOR_REDIRECT=$(echo "$COMMAND" | sed -E 's/[0-9]+>(>?)(\/dev\/null|&[0-9]+)//g')

  for pattern in "$WRITE_PATTERNS" "$GIT_WRITE" "$REDIRECT" "$PKG_WRITE" "$DOCKER_WRITE" "$CURL_WRITE" "$SED_WRITE" "$BACKTICK"; do
    CHECK_AGAINST="$COMMAND"
    # Only use the sanitized version for redirect checks
    if [ "$pattern" = "$REDIRECT" ]; then
      CHECK_AGAINST="$COMMAND_FOR_REDIRECT"
    fi
    if echo "$CHECK_AGAINST" | grep -qE "$pattern"; then
      exit 0  # Defer to permission system
    fi
  done

  # Check EVERY segment in pipeline/chain — all must be read-only to auto-approve.
  # Split on |, &&, ;, || and check each segment's leading command.
  # Note: tee and xargs intentionally excluded — they can write/exec arbitrary commands.
  # Note: node -e/python -c intentionally excluded — full languages can do anything.
  READONLY_CMDS="^(cd|pwd|ls|find|cat|head|tail|wc|file|stat|du|df|echo|printf|date|whoami|hostname|uname|env|printenv|which|type|command|realpath|dirname|basename|sort|uniq|tr|cut|awk|sed|grep|rg|jq|yq|diff|comm|tree|less|more|bat|fd|fzf|ps|top|htop|uptime|free|id|groups|locale|man|help|test|true|false|nproc|getconf|read|shasum|md5|md5sum|sha256sum|column|rev|tac|nl|fold|paste|join|expand|unexpand)$"
  # Multi-word read-only patterns (checked against stripped segment)
  GIT_READ="^[[:space:]]*git[[:space:]]+(log|status|diff|branch|show|remote|rev-parse|describe|shortlog|blame|ls-files|ls-tree|config[[:space:]]+--get)"
  GOG_READ="^[[:space:]]*gog[[:space:]]+(calendar|contacts|gmail|drive|sheets|docs)[[:space:]]+(events|list|get|search|read|view|messages[[:space:]]+search|cat|export|metadata)"
  BEEPER_READ="^[[:space:]]*(beeper-desktop-cli|beeper|scripts/beeper)[[:space:]]+(chats|messages|accounts|search|info)[[:space:]]*(list|search|retrieve|--|$)"
  GH_READ="^[[:space:]]*gh[[:space:]]+(pr[[:space:]]+(list|view|status|diff|checks)|issue[[:space:]]+(list|view|status)|run[[:space:]]+(list|view)|release[[:space:]]+(list|view)|repo[[:space:]]+view|auth[[:space:]]+status|search[[:space:]]|workflow[[:space:]]+(list|view))"
  # gh api is read-only only if it doesn't contain -X (method override) or --method
  GH_API_READ="^[[:space:]]*gh[[:space:]]+api[[:space:]]"
  GH_API_WRITE="-X[[:space:]]|--method[[:space:]]|-f[[:space:]]|-F[[:space:]]|--input[[:space:]]"

  ALL_READONLY=true
  # Split command into segments on |, &&, ;, ||
  while IFS= read -r segment; do
    # Strip leading whitespace, subshell parens, and trailing parens
    stripped=$(echo "$segment" | sed -E 's/^[[:space:]]*//; s/^[(]+[[:space:]]*//; s/[)]+[[:space:]]*$//')
    # Skip empty, comments, bare control tokens (done/fi/esac), and for-loop bindings
    if [ -z "$stripped" ] || echo "$stripped" | grep -qE '^(#|for[[:space:]]|(done|fi|esac)[[:space:]]*$)'; then continue; fi
    # Strip up to 2 leading control keywords for nesting
    # e.g. "do if test -f foo" → strip "do " → "if test -f foo" → strip "if " → "test -f foo"
    stripped=$(echo "$stripped" | sed -E 's/^(while|do|if|then|else|elif|case)[[:space:]]+//; s/^(while|do|if|then|else|elif|case)[[:space:]]+//')
    if [ -z "$stripped" ]; then continue; fi
    first_word=$(echo "$stripped" | awk '{print $1}')

    # Check single-word readonly commands, then multi-word patterns (git/gog/beeper)
    is_readonly=false
    if echo "$first_word" | grep -qE "$READONLY_CMDS"; then
      is_readonly=true
    fi
    if [ "$is_readonly" = false ]; then
      for pattern in "$GIT_READ" "$GOG_READ" "$BEEPER_READ" "$GH_READ"; do
        if echo "$stripped" | grep -qE "$pattern"; then
          is_readonly=true
          break
        fi
      done
    fi
    # gh api needs special handling: read-only unless it has -X/-f/-F/--method/--input
    if [ "$is_readonly" = false ] && echo "$stripped" | grep -qE "$GH_API_READ"; then
      if ! echo "$stripped" | grep -qE -- "$GH_API_WRITE"; then
        is_readonly=true
      fi
    fi

    if [ "$is_readonly" = false ]; then
      ALL_READONLY=false
      break
    fi
  done < <(echo "$COMMAND" | perl -pe 's/\|\||&&|;|\|/\n/g')

  if [ "$ALL_READONLY" = true ]; then
    approve "Read-only bash: auto-approved"
  fi

  # Unknown or mixed bash command → defer to permission system
  exit 0
fi

# ─── Everything else → ask user ──────────────────────────────────────────────

exit 0  # Defer to permission system
