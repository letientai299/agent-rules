#!/bin/bash

# preToolUse hook: block broad git staging commands.
# Multi-agent safety — always stage specific files.

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName')

# Only check bash commands
if [ "$TOOL_NAME" != "bash" ]; then
  exit 0
fi

CMD=$(echo "$INPUT" | jq -r '.toolArgs' | jq -r '.command // empty')

if echo "$CMD" | grep -qE 'git\s+add\s+(-A|--all|\.)(\s|$)'; then
  echo '{"permissionDecision":"deny","permissionDecisionReason":"Use git add <specific-files>, not git add -A or git add ."}'
  exit 0
fi

exit 0
