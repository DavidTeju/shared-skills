#!/bin/bash

# Claudeception Auto-Activation Hook
# Evaluates the session for extractable knowledge worth preserving.
#
# RECOMMENDED HOOK EVENT: Stop (fires once at session end)
#   - Injects this prompt only once, when the session is complete
#   - Same knowledge capture as UserPromptSubmit, ~95% less token waste
#   - Alternative: PreCompact (fires before context compaction — good for
#     capturing knowledge before it's summarized away)
#
# NOT RECOMMENDED: UserPromptSubmit
#   - Injects ~200 tokens on EVERY prompt, bloating context unnecessarily
#   - The evaluation only matters once per session, not per message
#
# Installation:
#   1. Copy this script to ~/.claude/hooks/
#   2. Make it executable: chmod +x ~/.claude/hooks/claudeception-activator.sh
#   3. Register as a "Stop" hook in ~/.claude/settings.json (see README)

cat << 'EOF'
🧠 Session complete. Evaluate: did this session produce extractable knowledge?
If debugging, non-obvious solutions, or reusable patterns emerged, activate
Skill(claudeception) to extract it. Skip if routine/trivial.
EOF
