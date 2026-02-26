# Multi-Agent Protocol

Multiple AI agents may work on the same codebase concurrently. Follow these
rules when committing or editing files.

## Commits

- **Stage by hunks, not files** — `git add -p <file>` to stage only your changed
  lines.
- **Never `git add -A` or `git add .`** — always be explicit.
- **Never stash** — affects the entire working tree.
- **Never amend or rewrite shared history** — no `--amend`, `rebase -i`,
  `push --force`.
- **Pull before committing** — `git pull --rebase`.
- **Retry on conflict** — re-pull and re-stage instead of forcing.
- **Don't affect others' work** — never reset, clean, or checkout files you
  didn't modify.
- **High-collision files** — lock files, project files, generated code. Avoid
  unnecessary changes; commit and push promptly.

## Atomic File Updates

- **Check before editing** — `git diff <file>` or `stat -f '%m' <file>` to
  detect changes since your last read. Only re-read if changed.
- **Minimize the read-edit gap** — no unrelated work between read and edit.
- **One agent per file at a time** — partition work by file/module to avoid
  overlap.
