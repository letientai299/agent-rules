# Q&A / Design Discussion Workflow

Key words MUST, MUST NOT, SHOULD, and MAY follow [RFC 2119][rfc2119].

## When to Use Q&A

MUST automatically start a Q&A file (without being asked) when ANY of these
apply:

- The task is unclear or ambiguous
- The code change spans more than 5 files or touches more than ~30 lines of
  logic
- There are multiple valid approaches with different trade-offs
- The task involves architectural or design decisions
- The user explicitly says "discuss", "review design", "qa", or "q&a"

MUST NOT ask the user whether to use Q&A — just do it. The user will not
explicitly mention `.ai.dump/` or filenames — auto-discover and use the
directory. MUST keep temp files in `.ai.dump/`, never in the repo root.

## File Naming

- MUST auto-generate filenames: `.ai.dump/<topic>-q<num>.md`
  - `<topic>` = short kebab-case slug derived from the task (e.g., `auth-flow`,
    `palette-ux`)
  - `<num>` = sequential within that topic (q1, q2, q3, ...)
  - MUST check existing `.ai.dump/` files to avoid collisions and continue
    numbering

## File Picking

When the user references a Q&A topic (e.g., "check qa", "continue the auth
discussion"):

- MUST scan `.ai.dump/` for matching files by topic keyword.
- If exactly one match: use it. MUST mention the relative path in your response.
- If multiple matches: MUST ask the user to pick using a combobox.
- If no match: tell the user no matching Q&A file was found.

MUST NOT require the user to type the full filename — infer it from context.

## Process

- Questions go in `.ai.dump/<topic>-q<num>.md` files.
- SHOULD cross-reference earlier files with relative links:
  `[<topic>-q1.md #4](./<topic>-q1.md)`.
- Research outputs go in `.ai.dump/<topic>.md` and SHOULD be linked from the Q
  file.
- The user answers inline in the same file (below each **Question:** block).
- After reading answers, MUST create the next `q<num+1>.md` with follow-ups.
- SHOULD keep a senior engineer voice — detailed analysis, reference links,
  concrete suggestions.
- SHOULD update project docs (e.g., `docs/`) with resolved decisions; mark open
  items with links back to the Q file.

[rfc2119]: https://www.ietf.org/rfc/rfc2119.txt
