# Global Agent Rules (Copilot)

Project-specific instructions override these rules.

Key words MUST, MUST NOT, SHOULD, and MAY follow [RFC 2119][rfc2119].

## Shared Rules

MUST read `~/.agent-rules/shared/general.md` at session start — contains
coding standards, git safety, commit conventions, tooling detection, and
artifact rules.

## Language Rules

MUST read the language file(s) matching the current project:

- `go.mod` present → MUST read `~/.agent-rules/shared/langs/go.md`
- `tsconfig.json` or `package.json` present → MUST read
  `~/.agent-rules/shared/langs/typescript.md`
- JSX/TSX files present → MUST also read `~/.agent-rules/shared/langs/react.md`

## Workflow Rules

<!-- TODO: auto-generate this list from shared/workflows/*.md during install -->

Read workflow files only when the session matches:

- Multi-agent session → `~/.agent-rules/shared/workflows/multi-agent.md`
- Code review requested → `~/.agent-rules/shared/workflows/code-review.md`
- Design discussion or Q&A → `~/.agent-rules/shared/workflows/qa.md`
- Writing documentation → `~/.agent-rules/shared/workflows/writing.md`
- Browser interaction or visual debugging → `~/.agent-rules/shared/workflows/browser.md`

[rfc2119]: https://www.ietf.org/rfc/rfc2119.txt
