#!/usr/bin/env bash
sid=$(jq -r '.session_id // empty')
[ -z "$sid" ] && exit 0

# Temp file keyed by Claude's PID (fallback)
echo "$sid" > "/tmp/.claude-sid-${PPID}"

# Inject as env var for all future Bash calls
if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo "CLAUDE_SESSION_ID=${sid}" >> "$CLAUDE_ENV_FILE"
fi
