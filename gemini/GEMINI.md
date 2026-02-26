# Global Agent Rules (Gemini)

These are my global coding rules. Project-specific `GEMINI.md` or `AGENTS.md`
files override these.

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

Read all shared rules and workflows at session start:

@~/.agent-rules/shared/global-core.md
@~/.agent-rules/shared/go.md
@~/.agent-rules/shared/typescript.md
@~/.agent-rules/shared/react.md
@~/.agent-rules/shared/workflows/multi-agent.md
@~/.agent-rules/shared/workflows/qa.md
@~/.agent-rules/shared/workflows/research.md
@~/.agent-rules/shared/workflows/code-review.md
@~/.agent-rules/shared/workflows/writing.md

## Artifacts

- All generated artifacts (screenshots, notes, scratch work) go in `.ai.dump/`
  at workspace root.
