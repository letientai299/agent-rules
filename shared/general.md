# Global Rules

Key words MUST, MUST NOT, SHOULD, and MAY follow [RFC 2119][rfc2119].

## Scope Guard

These rules apply **only when working on a code project** (i.e., the workspace
has source files you are creating or modifying). When the session is purely
conversational — general questions, research, brainstorming, or anything that
doesn't produce code changes — skip project-specific steps like linting,
formatting, building, and reading `AGENTS.md`. The **Artifacts** section is an
exception: MUST save research and reports even in conversational sessions.

## Style

- SHOULD prefer early-return over nested conditionals. Keep indentation minimal.
- MUST NOT duplicate code. Extract shared helpers when structural patterns
  repeat.
- MUST NOT add useless code, comments, or dependencies.
- SHOULD add detailed comments only for non-trivial logic. Include reference
  links.
- MUST NOT refactor beyond what the task requires.

## Quality

- MUST ensure no lint issues. MUST NOT suppress warnings (`//nolint`,
  `ts-ignore`, `any`, `eslint-disable`) unless there is a solid, documented
  reason — and even then, name the specific linter/rule and explain why in a
  comment.
- SHOULD consult official docs and forum discussions for library/framework APIs
  and bug workarounds.

## Testing

- MUST NOT generate test code unnecessarily. Add tests only for new features and
  bug fixes.
- SHOULD use table-driven / parameterized tests.
- SHOULD prefer unit tests. Use e2e tests only for complex flows.
- SHOULD add benchmarks for performance-critical code.

## Tooling Detection

MUST detect the project's toolchain from files at the workspace root. MUST NOT
hardcode tool names — discover them:

| File                        | Toolchain                                                                                                       |
| --------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `mise.toml` or `.mise.toml` | Use `mise` tasks (`mise build`, `mise test`, `mise lint`, `mise fmt`). Prefer mise over direct tool invocation. |
| `bun.lock` or `bun.lockb`   | Use `bun` as package manager and script runner.                                                                 |
| `pnpm-lock.yaml`            | Use `pnpm` as package manager and script runner.                                                                |
| `yarn.lock`                 | Use `yarn` as package manager and script runner.                                                                |
| `package-lock.json`         | Use `npm` as package manager and script runner.                                                                 |
| `go.mod`                    | Go project. Use `go build`, `go test`, etc. unless mise is also present.                                        |
| `Cargo.toml`                | Rust project. Use `cargo`.                                                                                      |
| `Makefile`                  | Use `make` targets when no higher-level task runner is present.                                                 |

When multiple files exist, SHOULD prefer the most specific runner: mise →
language-specific package manager → make. Check `package.json` scripts,
`mise.toml`, `Makefile` tasks for available commands. Ask if unclear — MUST NOT
guess.

## Language Rules

`~/.agent-rules/shared/langs/` contains language-specific rules. MUST read
**all** relevant files for the languages in use:

- `go.mod` present → MUST read `~/.agent-rules/shared/langs/go.md`
- `tsconfig.json` or `package.json` present → MUST read
  `~/.agent-rules/shared/langs/typescript.md`
- JSX/TSX files present → MUST also read `~/.agent-rules/shared/langs/react.md`

## Git Safety

- MUST stage files by explicit path. MUST NOT use `git add -A` or `git add .`.
- MUST NOT amend or rewrite shared history (`--amend`, `rebase -i`,
  `push --force`).
- MUST run `git pull --rebase` before committing.

## Commits

- MUST use conventional commit messages without scope (e.g., `fix:`, not
  `fix(ext):`). State _why_, not _what_. Subject ≤50 chars. Body wrapped at 80
  chars.

## Artifacts

- All generated artifacts (screenshots, notes, scratch work, reports) MUST go in
  `.ai.dump/` at the workspace root. MUST NOT place them in the repo root or
  `tmp/`. `.ai.dump/` is gitignored and disposable.
- MUST save detailed research findings, comparisons, and long-form explanations
  to a markdown file in `.ai.dump/`, even in conversational sessions.
- When creating or updating any artifact file (research, Q&A, code review, etc.)
  MUST add an attribution line at the bottom: `_Written by <cli> (<model>)_` —
  e.g., `_Written by claude (claude-sonnet-4-20250514)_`. If co-writing or
  updating an existing file, append `_Updated by <cli> (<model>)_` instead.
- SHOULD format markdown files (Q&A, reviews, research) with `prettier`. Use the
  project's config if present, otherwise default settings.

## Research Verification

Before finishing a code task, MUST verify technical decisions against official
docs using web search. This applies to:

- Library/framework API usage — confirm method signatures, options, deprecations
- Configuration formats — validate against current schema docs
- Platform-specific behavior — check OS/runtime version compatibility

Research is NOT needed for:

- Config-only edits with no new APIs or libraries
- Trivial changes (typos, formatting, renaming)
- Tasks entirely within well-known project code (no external dependencies)

When skipping, state the reason in one sentence (e.g., "No research needed —
config-only edit.").

## CLI

- SHOULD use modern CLI tools (rg, fd, jq) when available and applicable.

[rfc2119]: https://www.ietf.org/rfc/rfc2119.txt
