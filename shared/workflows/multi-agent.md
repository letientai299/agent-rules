# Multi-Agent Protocol

Multiple AI agents may work on the same codebase concurrently. Follow these
rules when committing or editing files.

## File Ownership

- **Partition by file/module** — each agent owns distinct files. Coordinate at
  the task level so no two agents edit the same file simultaneously.
- **Shared files** (Makefile, lock files, project configs) are high-collision.
  Edit them last, stage only your hunks, commit and push promptly.

## Staging

- **Never `git add -A` or `git add .`** — always name files explicitly.
- **Files you fully own** — `git add <file>` is fine when every change in the
  file is yours.
- **Shared files** — use `git add -p <file>` to stage only your hunks. Another
  agent may have added lines you shouldn't include.

## Commits

- **Pull before committing** — `git pull --rebase` to pick up other agents'
  work. If the pull surfaces changes in files you also modified, re-read those
  files and verify your edits still apply.
- **Retry on conflict** — re-pull and re-stage instead of forcing.
- **Never amend or rewrite shared history** — no `--amend`, `rebase -i`,
  `push --force`.
- **Never stash** — affects the entire working tree.
- **Don't affect others' work** — never reset, clean, or checkout files you
  didn't modify.
- **Complete units** — each commit must build and make sense on its own. Don't
  leave half-done work for another agent to fix.

## Atomic File Updates

- **Check before editing** — `git diff <file>` to detect changes since your last
  read. Re-read if changed.
- **Minimize the read-edit gap** — no unrelated work between read and edit.
