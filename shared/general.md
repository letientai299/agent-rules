# Global Rules

Key words MUST, MUST NOT, SHOULD, and MAY follow [RFC 2119][rfc2119].

## Scope Guard

These rules apply **only when working on a code project** (i.e., the workspace
has source files you are creating or modifying). When the session is purely
conversational — general questions, research, brainstorming, or anything that
doesn't produce code changes — skip everything under **Code Projects** below.
The remaining sections (Artifacts, Pushback, Link Integrity, Research
Verification, CLI) always apply.

## Artifacts

- All generated artifacts MUST go under `.ai.dump/<topic>/` at the workspace
  root, where `<topic>` is a short kebab-case slug derived from the task (e.g.,
  `auth-flow`, `palette-ux`). MUST NOT place them in the repo root, `tmp/`, or
  directly in `.ai.dump/`. `.ai.dump/` is gitignored and disposable.
- MUST check existing `.ai.dump/` subdirectories to avoid collisions and reuse
  an existing `<topic>/` folder when the work is related.
- **Artifact lookup:** when the user references an artifact by partial name
  (e.g., "check the research", "see q2", "read the review") without specifying
  the topic folder:
  1. Infer `<topic>` from the current conversation context.
  2. Look for the file inside `.ai.dump/<topic>/`.
  3. If no conversation context or no match, scan all `.ai.dump/*/` for the
     basename. One match → use it. Multiple → ask the user to pick. None →
     report not found.
- MUST save detailed research findings, comparisons, and long-form explanations
  to `.ai.dump/<topic>/research.md` (or a more specific name), even in
  conversational sessions.
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
  version** of the resource. MUST verify via web search or HTTP check (`curl`,
  `xh`, or `http`) before including a link. When neither web search nor HTTP
  tools are available, MUST NOT guess URLs. Omit the link and state the resource
  name so the user can find it.

## Research Verification

Before finishing a code task, SHOULD verify non-trivial technical decisions (new
API usage, unfamiliar library patterns, workarounds for known bugs) against
official docs, issue trackers, or forum discussions using web search when
available. Research is NOT needed for:

- Config-only edits with no new APIs or libraries
- Trivial changes (typos, formatting, renaming)
- Tasks entirely within well-known project code (no external dependencies)

When skipping, state the reason in one sentence (e.g., "No research needed —
config-only edit.").

## CLI

- SHOULD use modern CLI tools (rg, fd, jq) when available and applicable.

## Workflows

MUST read the relevant workflow file when the situation matches. All paths are
relative to `~/.agent-rules/shared/workflows/`.

| Situation                                        | File              |
| ------------------------------------------------ | ----------------- |
| Writing or editing markdown (docs, READMEs, etc) | `writing.md`      |
| Design discussion, ambiguous task, Q&A           | `qa.md`           |
| Code review (PR, file, diff)                     | `code-review.md`  |
| Browser interaction or visual debugging          | `browser.md`      |
| Interactive CLI/TUI tool (vim, fzf, less, REPLs) | `tmux-tui.md`     |
| Running dev servers (especially in worktrees)    | `dev-ports.md`    |
| Working in a git worktree                        | `worktree.md`     |
| Multiple agents in the same worktree             | `multi-agent.md`  |

---

# Code Projects

Sections below apply only when working on a code project. See Scope Guard.

## Style

- SHOULD prefer early-return over nested conditionals. Keep indentation minimal.
- MUST NOT add useless code, comments, or dependencies.
- SHOULD add detailed comments only for non-trivial logic. Include reference
  links.
- MUST NOT refactor beyond what the task requires.

## DRY and Single Responsibility

- MUST NOT duplicate code. Extract shared helpers when structural patterns
  repeat.
- **Search before writing:** before adding a new function, type, or module, MUST
  search the codebase for existing implementations that serve the same purpose.
  Use the most accurate method available, in order of preference:
  1. LSP tools (find references, go-to-definition) when an MCP language server
     is available.
  2. Language-specific CLI: `tsc --noEmit` (TS), `go vet` / `staticcheck` (Go),
     `cargo check` (Rust) — these understand types, not just text.
  3. AST-aware search or duplication detectors (`jscpd`, `golangci-lint` with
     `dupl` linter) when configured in the project.
  4. Grep/Glob as a last resort — effective for names but misses structural
     duplicates.
- **Single Responsibility indicators** — split when ANY of these apply:
  - A function has multiple unrelated reasons to change.
  - A file exports symbols that serve different concerns (e.g., parsing and
    rendering in the same module).
  - A function takes a boolean or mode flag that switches between two unrelated
    behaviors — split into two functions.
- **Post-change verification:** after extracting or consolidating shared code,
  MUST run the project's type checker / compiler before running the full test
  suite to catch breakage early.
- When reviewing code (own or others'), MUST flag DRY / SRP violations as
  **Important** findings. A duplicated bug that requires two fixes is a defect.

## API Design

Minimal API surface, deep flexibility. Prefer fewer entry points with composable
configuration over many specialized variants.

- Instead of `find_user_by_name_exact`, `find_user_by_name_contains`,
  `find_user_by_name_prefix` — use `find_user(query)` where `query` describes
  the match strategy.
- Instead of `do_something(opt1, opt2, opt3)` that breaks when adding `opt4` —
  use a config object or functional options pattern so new options are additive,
  not breaking.

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
- `.csproj` or `.sln` present → MUST read `~/.agent-rules/shared/langs/csharp.md`

## Local Overrides

### Machine-local

If `~/.agent-rules/local/agents.md` exists, MUST read it. Contains
machine-specific rules (e.g., toolchain preferences, paths). It MAY reference
other files within `~/.agent-rules/local/` using relative paths.

### Project-level overrides

MUST walk from the workspace root down to the current working directory, reading
rule files at each level (if they exist). This applies to every project,
regardless of whether any `AGENTS.md` exists:

1. At each directory from root to CWD, read `AGENTS.md` then `agents.local.md`.
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
  to verify only your changes are present. If the diff shows unexpected changes
  you did not make in this session, stop and ask the user before staging. MAY
  use `git apply --cached <patch>` to stage specific hunks when needed.
- MUST NOT commit unless the user explicitly requests it. A prior commit request
  does not authorize future auto-commits in subsequent tasks.
- MUST confirm with the user before any history-rewriting operation (amend,
  squash, rebase, reset, revert, cherry-pick, force-push).
- MUST NOT amend or rewrite shared history (`--amend`, `rebase -i`,
  `push --force`).
- SHOULD use `--ff-only` when merging feature branches into the main branch.
- SHOULD rebase feature branches onto `origin/main` before merging.

## Commits

- MUST use conventional commit messages without scope (e.g., `fix:`, not
  `fix(ext):`). State _why_, not _what_. Subject ≤50 chars. Body wrapped at 80
  chars.

[rfc2119]: https://www.ietf.org/rfc/rfc2119.txt
