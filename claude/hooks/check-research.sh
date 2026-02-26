#!/bin/bash

# Stop hook: warn once if no web research was done this session.
# First stop without research → block. Second stop → allow (agent justified it).

SESSION=$(cat | jq -r '.session_id')
MARKER="/tmp/claude-hooks/research-$SESSION"
WARNED="/tmp/claude-hooks/research-warned-$SESSION"

mkdir -p /tmp/claude-hooks

# Research was done — always allow
if [ -f "$MARKER" ]; then
  exit 0
fi

# Already warned once — allow (agent justified skipping research)
if [ -f "$WARNED" ]; then
  exit 0
fi

# First time — warn and block
touch "$WARNED"
cat >&2 <<'MSG'
Before finishing, if you haven't, use WebSearch to verify technical decisions
against official docs. If this task genuinely needs no research, justify.
MSG
exit 2
