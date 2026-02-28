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

## File Editing

- MUST use atomic file operations — read then edit in the tightest possible
  sequence with no unrelated work in between.
- SHOULD batch multiple edits to the same file in a single tool call rather than
  issuing repeated calls.

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

## Local Overrides

### Machine-local

If `~/.agent-rules/local/agents.md` exists, MUST read it. Contains
machine-specific rules (e.g., toolchain preferences, paths). It MAY reference
other files within `~/.agent-rules/local/` using relative paths.

### Hierarchical project discovery

In a monorepo, sub-packages may have their own `AGENTS.md` files. MUST walk from
the workspace root down to the current working directory, reading rule files at
each level:

1. At each directory from root to CWD, read `AGENTS.md` then `agents.local.md`
   (if they exist).
2. Closer files (nearer to CWD) take higher precedence over farther ones.
3. `agents.local.md` overrides `AGENTS.md` at the same level.

Precedence (lowest → highest):

```
~/.agent-rules/shared/                 (global shared rules)
~/.agent-rules/local/                  (machine-local overrides)
<root>/AGENTS.md
<root>/agents.local.md
<root>/packages/api/AGENTS.md
<root>/packages/api/agents.local.md
  ...down to CWD
```

`agents.local.md` contains personal or machine-specific project overrides and
SHOULD be gitignored by the developer.

## Git Safety

- MUST NOT use `git add -A` or `git add .`. Before staging, run `git diff <file>`
  to verify only your changes are present. When a file contains unrelated
  changes, write only your hunks to a temp patch and stage them with
  `git apply --cached <patch>`. MUST NOT stage hunks you did not author.
- MUST confirm with the user before any git history modification (commit, amend,
  squash, rebase, reset, revert, cherry-pick, etc.).
- MUST NOT amend or rewrite shared history (`--amend`, `rebase -i`,
  `push --force`).
- SHOULD use `--ff-only` when merging feature branches into the main branch.
- SHOULD rebase feature branches onto `origin/main` before merging.

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
  MUST add an `## Authors` section at the bottom with list entries. When
  creating a new file, add `- Written by <cli> (<model>) at <YYYY-MM-DD HH:MM>`.
  When updating an existing file, append
  `- Updated by <cli> (<model>) at <YYYY-MM-DD HH:MM>` on a new list item. Use
  local time. List syntax prevents prettier from joining lines.

  ```md
  ## Authors

  - Written by claude (claude-opus-4-6) at 2026-02-28 14:30
  - Updated by claude (claude-sonnet-4-6) at 2026-03-01 09:15
  ```
- When an artifact contains items needing user decision (questions, review
  findings, design choices), the first agent MUST add a `**Answer:**`
  placeholder for each. Other agents updating the file later MUST NOT write into
  `**Answer:**` placeholders — they are reserved for the user.
- MUST format markdown files (Q&A, reviews, research) with `prettier`. Use the
  project's config if present, otherwise default settings.

## Pushback

- MAY counter the user's or another agent's opinion, proposal, or review
  feedback when the reasoning is flawed or the conclusion is likely wrong. MUST
  back the disagreement with concrete examples, evidence, or reference links —
  never push back on vibes alone.

## Link Integrity

- All links provided MUST be valid, reachable, and point to the **latest stable
  version** of the resource. MUST verify via web search before including a link.
- MUST NOT guess URLs. If the canonical URL cannot be confirmed, omit the link
  and state the resource name so the user can find it.

## Research Verification

Before finishing a code task, MUST verify claims, technical decisions against
official docs, issues trackers, forum discussions using web search. Research is
NOT needed for:

- Config-only edits with no new APIs or libraries
- Trivial changes (typos, formatting, renaming)
- Tasks entirely within well-known project code (no external dependencies)

When skipping, state the reason in one sentence (e.g., "No research needed —
config-only edit.").

## CLI

- SHOULD use modern CLI tools (rg, fd, jq) when available and applicable.

[rfc2119]: https://www.ietf.org/rfc/rfc2119.txt
