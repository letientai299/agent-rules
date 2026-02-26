#!/bin/bash

# preToolUse hook: warn before git commit if no web research was done.
# Copilot has no "Stop" hook, so we enforce at commit time instead.
# First commit attempt without research → deny. Second attempt → allow
# (agent justified skipping research in the deny message).

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName')

# Only intercept bash commands that look like git commit
if [ "$TOOL_NAME" != "bash" ]; then
  exit 0
fi

CMD=$(echo "$INPUT" | jq -r '.toolArgs' | jq -r '.command // empty')

if ! echo "$CMD" | grep -qE 'git\s+commit'; then
  exit 0
fi

CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
HASH=$(echo "$CWD" | shasum | cut -d' ' -f1)
MARKER="/tmp/copilot-hooks/research-$HASH"
WARNED="/tmp/copilot-hooks/research-warned-$HASH"

mkdir -p /tmp/copilot-hooks

# Research was done — allow
if [ -f "$MARKER" ]; then
  exit 0
fi

# Already warned once — allow (agent justified skipping)
if [ -f "$WARNED" ]; then
  exit 0
fi

# First time — warn and deny
touch "$WARNED"
echo '{"permissionDecision":"deny","permissionDecisionReason":"Before committing, use web search to verify technical decisions against official docs. If no research is needed, justify why and commit again."}'
exit 0
