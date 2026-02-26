# Q&A / Design Discussion Workflow

## When to use Q&A

Automatically start a Q&A file (without being asked) when ANY of these apply:

- The task is unclear or ambiguous
- The code change spans more than 5 files or touches more than ~30 lines of
  logic
- There are multiple valid approaches with different trade-offs
- The task involves architectural or design decisions
- The user explicitly says "discuss", "review design", "qa", or "q&a"

Do NOT ask the user whether to use Q&A — just do it. The user will not
explicitly mention `.ai.dump/` or filenames — auto-discover and use the
directory. Always keep temp files in `.ai.dump/`, never in the repo root (to
avoid accidental commits).

## File naming

- Auto-generate filenames: `.ai.dump/<topic>-q<num>.md`
  - `<topic>` = short kebab-case slug derived from the task (e.g., `auth-flow`,
    `palette-ux`)
  - `<num>` = sequential within that topic (q1, q2, q3, ...)
  - Check existing `.ai.dump/` files to avoid collisions and continue numbering

## File picking

When the user references a Q&A topic (e.g., "check qa", "continue the auth
discussion"):

- Scan `.ai.dump/` for matching files by topic keyword.
- If exactly one match: use it. Always mention the relative path (e.g.,
  `.ai.dump/auth-q2.md`) in your response so the user knows which file you're
  working with.
- If multiple matches: ask the user to pick using a combobox (AskUserQuestion
  with options listing the matching filenames).
- If no match: tell the user no matching Q&A file was found.

Never require the user to type the full filename — infer it from context.

## Process

- Questions go in `.ai.dump/<topic>-q<num>.md` files.
- Cross-reference earlier files with relative links:
  `[<topic>-q1.md #4](./<topic>-q1.md)`.
- Research outputs go in `.ai.dump/<topic>.md` and are linked from the Q file.
- The user answers inline in the same file (below each **Question:** block).
- After reading answers, create the next `q<num+1>.md` with follow-ups.
- Keep a senior engineer voice — detailed analysis, reference links, concrete
  suggestions.
- Update project docs (e.g., `docs/`) with resolved decisions; mark open items
  with links back to the Q file.
