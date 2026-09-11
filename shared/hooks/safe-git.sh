#!/bin/bash

# Block broad git staging. Payload shapes:
# Claude/Codex PreToolUse: .tool_input.command
# Cursor beforeShellExecution: .command

set -euo pipefail

input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // .command // empty')
# Cursor beforeShellExecution: {command, cwd}. Claude/Codex PreToolUse: {tool_input}.
cursor=false
if echo "$input" | jq -e 'has("command") and (has("tool_input") | not)' >/dev/null; then
	cursor=true
fi

if echo "$cmd" | grep -qE 'git\s+add\s+(-A|--all|\.)(\s|$)'; then
	reason="Blocked: use 'git add <specific-files>', not 'git add -A' or 'git add .'"
	echo "$reason" >&2
	if [[ "$cursor" == true ]]; then
		jq -n --arg msg "$reason" \
			'{permission:"deny", agent_message:$msg, user_message:$msg}'
		exit 0
	fi
	exit 2
fi

if [[ "$cursor" == true ]]; then
	echo '{ "permission": "allow" }'
fi
exit 0
