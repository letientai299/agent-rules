#!/bin/bash
# PostToolUse hook: format markdown files after Write/Edit operations.
# Claude Code passes JSON on stdin, not as positional arguments.
# Uses --ignore-path='' because prettier v3+ skips gitignored files by default.

set -euo pipefail

input=$(cat)

file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# Only format markdown files that exist
if [[ "$file_path" == *.md ]] && [[ -f "$file_path" ]]; then
	if command -v prettier &>/dev/null; then
		prettier --write --ignore-path='' "$file_path" 2>/dev/null || true
	fi
fi

exit 0
