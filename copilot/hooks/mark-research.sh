#!/bin/bash

# postToolUse hook: mark that web research happened this session.
# Uses a temp file keyed by working directory to track across tool calls.

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName')

# Only mark on web search/fetch tools
case "$TOOL_NAME" in
  web_search|web_fetch|WebSearch|WebFetch) ;;
  *) exit 0 ;;
esac

CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
HASH=$(echo "$CWD" | shasum | cut -d' ' -f1)
mkdir -p /tmp/copilot-hooks
touch "/tmp/copilot-hooks/research-$HASH"
exit 0
