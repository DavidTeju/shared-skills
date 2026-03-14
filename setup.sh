#!/usr/bin/env bash
# setup.sh — Set up shared skills for Claude Code (local) or OpenClaw (VPS)
#
# Usage:
#   ./setup.sh local           # Symlink skills into Claude Code directories
#   ./setup.sh openclaw        # Deploy to OpenClaw VPS via git clone + symlinks
#   ./setup.sh local --dry-run # Preview changes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/skills"
HOOKS_DIR="$SCRIPT_DIR/hooks"
DRY_RUN=false

# ═══════════════════════════════════════════════════════════
# Skill routing — defines where each skill gets symlinked.
# Every skill in skills/ should appear in exactly one list.
# ═══════════════════════════════════════════════════════════

# ── User-level: loaded in ALL Claude Code projects ──
# (~/.claude/skills/)
USER_SKILLS=(
  # General engineering patterns
  ai-agent-debugging-guide
  async-dedup-race-in-streaming-pipelines
  fix-at-appropriate-layer
  git-commit-practices
  test-debugging-without-hacking

  # Agent/orchestration
  agent-team-orchestration-patterns
  bug-basher-5000
  create-cli-skill
  claude-code-session-transcript-analysis
  claude-code-token-usage
  claudeception
  code-review
  ralph-wiggum-loop-setup

  # macOS / system
  browser-tab-resource-investigation
  playwright-cli
  swift-macos-native-apis
  speech-to-text

  # Google tools
  gog
  google-calendar-ics-timezone-handling

  # Notion (generic)
  notion-child-page-preservation
  notion-page-link-syntax

  # Next.js / Prisma
  git-worktree-nextjs-prisma
  nextjs-client-server-boundary-dns-error
  nextjs-prisma-client-component-import
  prisma-7-driver-adapter
  prisma-migration-drift-recovery

  # Writing
  humanizer

  # Svelte
  svelte-best-practices

  # TypeScript
  typescript-best-practices

  # Vitest
  vitest-class-mocking
  vitest-mock-implementation-persistence
  vitest-recharts-mocking
)

# ── Project: personal_assistant_claude ──
# (~/projects/personal_assistant_claude/.claude/skills/)
PA_PROJECT_SKILLS=(
  beeper
  femi-calendar
  macos-messages-contacts-access
  message-review
  notion-style-matching
  notion-todo-organization
  querying-and-updating-notion
  swarm-research
)

# ── Project: peronal_budget_tracking ──
# (~/projects/peronal_budget_tracking/.claude/skills/)
BUDGET_PROJECT_SKILLS=(
  architecture-parity-review
  multi-agent-orchestration
)

# ── Parse args ──
TARGET="${1:-}"
shift || true
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
  esac
done

if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 <local|openclaw> [--dry-run]"
  exit 1
fi

symlink_skill() {
  local skill="$1"
  local target_dir="$2"

  local src="$SKILLS_DIR/$skill"
  local dst="$target_dir/$skill"

  if [[ ! -d "$src" ]]; then
    echo "  SKIP $skill (not in shared-skills/skills/)"
    return
  fi

  if $DRY_RUN; then
    echo "  WOULD LINK $dst → $src"
    return
  fi

  # Remove existing (dir or symlink) and replace with symlink
  if [[ -e "$dst" || -L "$dst" ]]; then
    rm -rf "$dst"
  fi
  ln -s "$src" "$dst"
  echo "  ✓ $skill"
}

# ═══════════════════════════════════════════════════════════
# Hook registration in settings.json
# Maps hook files to their event types for auto-registration.
# Format: "filename:EventType"
# ═══════════════════════════════════════════════════════════
HOOK_REGISTRATIONS=(
  "readonly-gate.sh:PreToolUse"
  "eslint-disable-blocker.sh:PreToolUse"
  "eslint-config-protector.sh:PreToolUse"
  "lint-feedback-loop.sh:PostToolUse"
  "claudeception-activator.sh:UserPromptSubmit"
)

register_hook() {
  local settings_file="$1"
  local event_type="$2"
  local hook_command="$3"

  if $DRY_RUN; then
    echo "  WOULD REGISTER $event_type → $hook_command in $settings_file"
    return
  fi

  python3 "$SCRIPT_DIR/scripts/register_hook.py" "$settings_file" "$event_type" "$hook_command"
}

unregister_hook() {
  local settings_file="$1"
  local hook_command="$2"

  [[ ! -f "$settings_file" ]] && return

  if $DRY_RUN; then
    echo "  WOULD UNREGISTER $hook_command from $settings_file"
    return
  fi

  python3 "$SCRIPT_DIR/scripts/unregister_hook.py" "$settings_file" "$hook_command"
}

symlink_hook() {
  local file="$1"
  local target_dir="$2"

  local name
  name=$(basename "$file")
  local dst="$target_dir/$name"

  if [[ ! -f "$file" ]]; then
    echo "  SKIP $name (not found)"
    return
  fi

  if $DRY_RUN; then
    echo "  WOULD LINK $dst → $file"
    return
  fi

  if [[ -e "$dst" || -L "$dst" ]]; then
    rm -f "$dst"
  fi
  ln -s "$file" "$dst"
  echo "  ✓ $name"
}

# ── Local setup (Claude Code) ──
setup_local() {
  local claude_user="$HOME/.claude/skills"
  mkdir -p "$claude_user"

  echo "User-level skills → $claude_user"
  for skill in "${USER_SKILLS[@]}"; do
    symlink_skill "$skill" "$claude_user"
  done

  # ── Project-specific skills (only if the project exists) ──
  local claude_pa="$HOME/projects/personal_assistant_claude/.claude/skills"
  if [[ -d "$HOME/projects/personal_assistant_claude" ]]; then
    mkdir -p "$claude_pa"
    echo ""
    echo "Project: personal_assistant_claude → $claude_pa"
    for skill in "${PA_PROJECT_SKILLS[@]}"; do
      symlink_skill "$skill" "$claude_pa"
    done
  fi

  local claude_budget="$HOME/projects/peronal_budget_tracking/.claude/skills"
  if [[ -d "$HOME/projects/peronal_budget_tracking" ]]; then
    mkdir -p "$claude_budget"
    echo ""
    echo "Project: peronal_budget_tracking → $claude_budget"
    for skill in "${BUDGET_PROJECT_SKILLS[@]}"; do
      symlink_skill "$skill" "$claude_budget"
    done
  fi

  # ── Hooks ──
  local user_hooks="$HOME/.claude/hooks"

  mkdir -p "$user_hooks"

  echo ""
  echo "User-level hooks → $user_hooks"
  for f in "$HOOKS_DIR"/user-level/*; do
    [[ -f "$f" ]] && symlink_hook "$f" "$user_hooks"
  done

  # ── Register hooks in settings.json ──
  local user_settings="$HOME/.claude/settings.json"
  echo ""
  echo "Hook registration → $user_settings"
  for entry in "${HOOK_REGISTRATIONS[@]}"; do
    local filename="${entry%%:*}"
    local event="${entry##*:}"
    local cmd="~/.claude/hooks/$filename"
    if [[ -L "$user_hooks/$filename" || -f "$user_hooks/$filename" ]]; then
      register_hook "$user_settings" "$event" "$cmd"
      echo "  ✓ $event → $cmd"
    fi
  done

  # ── Clean stale project-level hook registrations ──
  # When hooks move from project to user level, remove old entries.
  local pa_settings="$HOME/projects/personal_assistant_claude/.claude/settings.json"
  if [[ -f "$pa_settings" ]]; then
    for entry in "${HOOK_REGISTRATIONS[@]}"; do
      local filename="${entry%%:*}"
      unregister_hook "$pa_settings" "\$CLAUDE_PROJECT_DIR/.claude/hooks/$filename"
    done
  fi

  echo ""
  if $DRY_RUN; then
    echo "Dry run complete."
  else
    echo "Done. Claude Code will pick these up on next session."
  fi
}

# ── OpenClaw setup (VPS) ──
# Pulls latest from GitHub and symlinks into OpenClaw's skill directory.
# Requires: deploy key on VPS with access to DavidTeju/shared-skills (already configured).
setup_openclaw() {
  local HOST="openclaw"
  local REMOTE_REPO="/root/shared-skills"
  local REMOTE_SKILLS="$REMOTE_REPO/skills"
  local OPENCLAW_SKILLS="/root/.openclaw/skills"

  if ! ssh -o ConnectTimeout=5 "$HOST" "true" 2>/dev/null; then
    echo "ERROR: Cannot reach OpenClaw VPS ($HOST)"
    exit 1
  fi

  if $DRY_RUN; then
    echo "Would git pull on $HOST:$REMOTE_REPO"
    echo "Would symlink all skills into $OPENCLAW_SKILLS"
    return
  fi

  # Pull latest from GitHub
  echo "Pulling latest on VPS..."
  ssh "$HOST" "cd $REMOTE_REPO && git pull --ff-only"

  # Symlink any new skills (idempotent)
  echo "Updating symlinks..."
  ssh "$HOST" "mkdir -p $OPENCLAW_SKILLS && for skill in $REMOTE_SKILLS/*/; do name=\$(basename \"\$skill\"); rm -rf $OPENCLAW_SKILLS/\$name; ln -s \"\$skill\" $OPENCLAW_SKILLS/\$name; echo \"  ✓ \$name\"; done"

  echo ""
  echo "Done. Skills are up to date on $HOST."
}

# ── Dispatch ──
case "$TARGET" in
  local)    setup_local ;;
  openclaw) setup_openclaw ;;
  *)
    echo "Unknown target: $TARGET"
    echo "Usage: $0 <local|openclaw> [--dry-run]"
    exit 1
    ;;
esac
