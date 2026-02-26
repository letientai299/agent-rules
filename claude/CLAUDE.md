# Global Agent Rules

## Scope Guard

These rules apply **only when working on a code project** (i.e., the workspace
has source files you are creating or modifying). When the session is purely
conversational — general questions, research, brainstorming, or anything that
doesn't produce code changes — skip project-specific steps like linting,
formatting, building, and reading `AGENTS.md`.

## Hook Responses

When a hook blocks with a message, respond with **one short sentence** — no
elaboration, no bullet points, no restating the hook's message. Example: "No
research needed — config-only edit."

## Before Starting a Code Task

- Read and follow the project's `AGENTS.md` if it exists in the workspace root.

## Language Rules

`~/.agent-rules/shared/` contains language-specific rules. Read **all** relevant
files for the languages in use. React rules always apply alongside TypeScript
when JSX/TSX files are present.

- Go → `~/.agent-rules/shared/go.md`
- TypeScript → `~/.agent-rules/shared/typescript.md`
- React → `~/.agent-rules/shared/react.md`
