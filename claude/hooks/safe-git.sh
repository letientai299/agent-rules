#!/bin/bash

# PreToolUse hook: block broad git staging commands.
# Multi-agent safety — always stage specific files.

CMD=$(cat | jq -r '.tool_input.command // empty')

if echo "$CMD" | grep -qE 'git\s+add\s+(-A|--all|\.)(\s|$)'; then
  echo "Blocked: use 'git add <specific-files>', not 'git add -A' or 'git add .'" >&2
  exit 2
fi

exit 0
