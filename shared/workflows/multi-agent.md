# Multi-Agent Protocol

Key words MUST, MUST NOT, SHOULD, and MAY follow [RFC 2119][rfc2119].

Multiple AI agents MAY work on the same codebase concurrently. Follow these
rules when committing or editing files.

## File Ownership

- SHOULD partition by file/module — each agent owns distinct files. Coordinate
  at the task level so no two agents edit the same file simultaneously.
- Shared files (Makefile, lock files, project configs) are high-collision. MUST
  edit them last, stage only your hunks, commit and push promptly.

## Staging

Core staging rules (MUST stage by path, MUST NOT `git add -A`) live in
`general.md`. Additional multi-agent rules:

- Files you fully own — `git add <file>` is fine when every change in the file
  is yours.
- Shared files — MUST use `git add -p <file>` to stage only your hunks. Another
  agent may have added lines you MUST NOT include.

## Commits

Core commit rules (MUST pull before commit, MUST NOT amend shared history) live
in `general.md`. Additional multi-agent rules:

- MUST retry on conflict — re-pull and re-stage instead of forcing.
- MUST NOT stash — affects the entire working tree.
- MUST NOT reset, clean, or checkout files you didn't modify.
- MUST commit complete units — each commit MUST build and make sense on its own.

## Atomic File Updates

- MUST check before editing — `git diff <file>` to detect changes since your
  last read. Re-read if changed.
- SHOULD minimize the read-edit gap — no unrelated work between read and edit.

[rfc2119]: https://www.ietf.org/rfc/rfc2119.txt
