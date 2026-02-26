#!/bin/bash

# PostToolUse hook: mark that web research happened this session.

SESSION=$(cat | jq -r '.session_id')
mkdir -p /tmp/claude-hooks
touch "/tmp/claude-hooks/research-$SESSION"
exit 0
