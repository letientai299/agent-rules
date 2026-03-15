#!/bin/bash
# PostToolUse hook: format markdown files after Write/Edit operations.

set -euo pipefail

TOOL="$1"
RESULT="$2"

# Only run on Write or Edit tools
if [[ "$TOOL" != "Write" && "$TOOL" != "Edit" ]]; then
	exit 0
fi

# Check if result indicates success
if [[ "$RESULT" != *"success"* ]]; then
	exit 0
fi

# Extract file path from result - looks for patterns like:
# "Wrote: /path/to/file.md" or "/path/to/file.md"
FILE_PATH=$(echo "$RESULT" | grep -oE '/[^ ]+\.md' | head -1 || true)

if [[ -z "$FILE_PATH" ]]; then
	exit 0
fi

# Only format files in .ai.dump or markdown files generally
if [[ "$FILE_PATH" == *.md ]] && [[ -f "$FILE_PATH" ]]; then
	# Check if prettier is available
	if command -v prettier &>/dev/null; then
		prettier --write "$FILE_PATH" 2>/dev/null || true
	fi
fi

exit 0
