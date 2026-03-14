#!/usr/bin/env bash
# lint-feedback-loop — PostToolUse hook that runs ESLint after file edits.
#
# After Write/Edit, runs eslint on the file. If it fails, feeds errors
# back to the agent. Tracks attempts per file — after 3 failures on the
# same file, tells the agent to stop and ask the human for help.
#
# Only runs on lintable files (.js, .ts, .tsx, .jsx, .mjs, .cjs, .mts, .cts).
# Silently passes if eslint is not installed or the file has no eslint config.

set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')

# Only care about file-writing tools
case "$TOOL_NAME" in
  Write|Edit|NotebookEdit) ;;
  *) exit 0 ;;
esac

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
[[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]] && exit 0

# Only lint JS/TS files
case "$FILE_PATH" in
  *.js|*.ts|*.tsx|*.jsx|*.mjs|*.cjs|*.mts|*.cts) ;;
  *) exit 0 ;;
esac

# Find project root (nearest package.json or git root)
PROJECT_ROOT=""
dir=$(dirname "$FILE_PATH")
while [[ "$dir" != "/" ]]; do
  if [[ -f "$dir/package.json" ]]; then
    PROJECT_ROOT="$dir"
    break
  fi
  dir=$(dirname "$dir")
done
[[ -z "$PROJECT_ROOT" ]] && exit 0

# Check for eslint config in project
HAS_CONFIG=false
for cfg in eslint.config.js eslint.config.mjs eslint.config.cjs eslint.config.ts eslint.config.mts eslint.config.cts .eslintrc .eslintrc.js .eslintrc.cjs .eslintrc.json .eslintrc.yml .eslintrc.yaml; do
  if [[ -f "$PROJECT_ROOT/$cfg" ]]; then
    HAS_CONFIG=true
    break
  fi
done

# Also check package.json for eslintConfig key
if ! $HAS_CONFIG && grep -q '"eslintConfig"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
  HAS_CONFIG=true
fi

$HAS_CONFIG || exit 0

# Find eslint binary
ESLINT=""
if [[ -x "$PROJECT_ROOT/node_modules/.bin/eslint" ]]; then
  ESLINT="$PROJECT_ROOT/node_modules/.bin/eslint"
elif command -v eslint &>/dev/null; then
  ESLINT="eslint"
else
  exit 0
fi

# ── Auto-fix first, then check for remaining errors ──
# Run from project root so plugins resolve correctly (e.g. prettier-plugin-svelte).
cd "$PROJECT_ROOT"

# Fix trivial issues (formatting, auto-fixable rules) silently.
# Only non-auto-fixable errors count as strikes.
"$ESLINT" --fix --no-warn-ignored "$FILE_PATH" >/dev/null 2>&1 || true

LINT_EXIT_CODE=0
LINT_OUTPUT=$("$ESLINT" --no-warn-ignored "$FILE_PATH" 2>&1) || LINT_EXIT_CODE=$?

# Lint passed — reset attempt counter and exit silently
if [[ $LINT_EXIT_CODE -eq 0 ]]; then
  # Clear attempt counter for this file
  TRACK_DIR="/tmp/claude-lint-attempts"
  SAFE_NAME=$(echo "$FILE_PATH" | sed 's|/|__|g')
  rm -f "$TRACK_DIR/$SAFE_NAME" 2>/dev/null
  exit 0
fi

# ── Lint failed — track attempts ──
TRACK_DIR="/tmp/claude-lint-attempts"
mkdir -p "$TRACK_DIR"
SAFE_NAME=$(echo "$FILE_PATH" | sed 's|/|__|g')
TRACK_FILE="$TRACK_DIR/$SAFE_NAME"

ATTEMPT=0
if [[ -f "$TRACK_FILE" ]]; then
  ATTEMPT=$(cat "$TRACK_FILE")
fi
ATTEMPT=$((ATTEMPT + 1))
echo "$ATTEMPT" > "$TRACK_FILE"

# Truncate lint output to avoid massive payloads
LINT_TRUNCATED=$(echo "$LINT_OUTPUT" | head -40)

if [[ $ATTEMPT -ge 3 ]]; then
  # Three strikes — escalate to human
  rm -f "$TRACK_FILE"
  REASON=$(cat <<'INNEREOF'
CRITICAL: This file has failed linting 3 times in a row.

STOP. Do not attempt to fix this file again.
Report to the user:
  1. Which file is failing
  2. Which ESLint rules are being violated
  3. What you've tried so far
  4. Why you think you can't resolve it

Let the human decide the next step.
INNEREOF
  )
  # Append lint output
  REASON="$REASON

Last lint output:
$LINT_TRUNCATED"

  jq -n --arg reason "$REASON" '{
    decision: "block",
    reason: $reason
  }'
else
  REASON=$(cat <<INNEREOF
ESLint errors detected in $FILE_PATH (attempt $ATTEMPT/3).
Fix these errors before moving on:

$LINT_TRUNCATED
INNEREOF
  )
  jq -n --arg reason "$REASON" --arg ctx "Lint errors must be fixed. You have $((3 - ATTEMPT)) attempt(s) remaining before escalation to the user." '{
    decision: "block",
    reason: $reason,
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: $ctx
    }
  }'
fi
