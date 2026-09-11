#!/bin/bash

# beforeShellExecution: block broad git staging commands.
# Multi-agent safety — always stage specific files.

set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.command // empty')

if echo "$command" | grep -qE 'git\s+add\s+(-A|--all|\.)(\s|$)'; then
  reason="Blocked: use 'git add <specific-files>', not 'git add -A' or 'git add .'"
  jq -n --arg msg "$reason" \
    '{permission:"deny", agent_message:$msg, user_message:$msg}'
  exit 0
fi

echo '{ "permission": "allow" }'
exit 0
