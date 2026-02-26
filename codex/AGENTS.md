# Global Agent Rules (Codex)

These are my global coding rules. Project-specific `AGENTS.md` files override
these.

## Coding

- Prefer early-return over nested conditionals. Keep indentation minimal.
- DRY. Extract shared helpers when structural patterns repeat.
- Don't add useless code, comments, or dependencies.
- Don't suppress lint warnings. If suppression is truly necessary, name the
  specific rule and explain why in a comment.
- Minimal code changes — don't refactor beyond what's needed.
- Consult official docs for library/framework APIs and bug workarounds.
- Use conventional commit messages without scope. State _why_, not _what_.
- Use table-driven / parameterized tests. Prefer unit tests.

## Tooling

Detect the project's toolchain from files at the workspace root (mise.toml,
bun.lock, pnpm-lock.yaml, go.mod, Cargo.toml, Makefile, ...). Use the detected
runner for build, test, lint, format commands. Ask if unclear, don't guess.

## Git Safety

- Stage specific files, never `git add -A` or `git add .`.
- Never amend or rewrite shared history.
- Pull before committing (`git pull --rebase`).

## Shared Rules

At session start, read **all** `.md` files in `~/.agent-rules/shared/` and
`~/.agent-rules/shared/workflows/`. These contain language-specific rules, core
coding rules, and workflow policies. Read all relevant language files for the
languages in use. React rules always apply alongside TypeScript when JSX/TSX
files are present.
