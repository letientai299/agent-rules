# Coding Rules

## Style

- Prefer early-return over nested conditionals. Keep indentation minimal.
- DRY. Extract shared helpers when structural patterns repeat.
- Don't add useless code, comments, or dependencies.
- Add detailed comments only for non-trivial logic. Include reference links.
- Minimal code changes — don't refactor beyond what's needed.

## Quality

- Ensure no lint issues. Never suppress warnings (`//nolint`, `ts-ignore`,
  `any`, `eslint-disable`) unless there is a solid, documented reason — and even
  then, name the specific linter/rule and explain why in a comment.
- Consult official docs and forum discussions for library/framework APIs and bug
  workarounds.

## Testing

- Use table-driven / parameterized tests.
- Prefer unit tests. Use e2e tests only for complex flows.
- Add benchmarks for performance-critical code.

## Tooling Detection

Detect the project's toolchain from files at the workspace root. Don't hardcode
tool names in rules — discover them:

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

When multiple files exist, prefer the most specific runner: mise,
language-specific package manager, make, ... Check `package.json` scripts,
`mise.toml`, `Makefile`, ...tasks for available commands. Ask if unclear, don't
guess.

## Commits

- Use conventional commit messages without scope (e.g., `fix:`, not
  `fix(ext):`). State _why_, not _what_. Subject ≤50 chars. Body wrapped at 80
  chars.

## Artifacts

- All generated artifacts (screenshots, notes, scratch work, reports) go in
  `.ai.dump/` at the workspace root. Never in the repo root or `tmp/`.
  `.ai.dump/` is gitignored and disposable.
- Format markdown files (Q&A, reviews, research) with `prettier`. Use the
  project's config if present, otherwise default settings. Prettier is globally
  installed on all machines.

## CLI

- Use modern CLI tools (rg, fd, jq) when available and applicable
