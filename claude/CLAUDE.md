# Global Agent Rules

## Hook Responses

When a hook blocks with a message, respond with **one short sentence** — no
elaboration, no bullet points, no restating the hook's message. Example: "No
research needed — config-only edit."

## Session ID

The session ID is available as `$CLAUDE_SESSION_ID` in Bash (set by a
`SessionStart` hook). If empty, fall back to
`cat /tmp/.claude-sid-$PPID`. Use this when writing `## Authors` sections in
artifacts.

## Before Starting a Code Task

- Discover and read project rule files (`AGENTS.md` and `agents.local.md`) per
  the Local Overrides section in `shared/general.md`.
