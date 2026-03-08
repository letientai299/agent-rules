# Design discussion or Q&A

Key words MUST, MUST NOT, SHOULD, and MAY follow [RFC 2119][rfc2119].

## When to Use Q&A

MUST automatically start a Q&A file (without being asked) when ANY of these
apply:

- The task is unclear or ambiguous
- The code change is expected to span more than 5 files or involve significant
  logic changes
- There are multiple valid approaches with different trade-offs
- The task involves architectural or design decisions
- The user explicitly says "discuss", "review design", "qa", or "q&a"

MUST NOT ask the user whether to use Q&A — just do it. The user will not
explicitly mention `.ai.dump/` or filenames — auto-discover and use the
directory. MUST keep temp files in `.ai.dump/`, never in the repo root.

## File Naming

- MUST place Q&A files under `.ai.dump/<topic>/q<num>.md`.
  - `<topic>` = short kebab-case slug derived from the task (e.g., `auth-flow`,
    `palette-ux`).
  - `<num>` = sequential within that topic (q1, q2, q3, ...).
  - MUST check existing `.ai.dump/<topic>/` files to continue numbering.

## File Picking

Follow the [artifact lookup rules][artifacts] in general.md. Additionally, when
the user says "continue the discussion" or "check qa" without naming a topic,
MUST infer the topic from the current conversation and open the latest
`q<num>.md` in that topic folder.

## Process

- Questions go in `.ai.dump/<topic>/q<num>.md` files.
- SHOULD cross-reference earlier files with relative links:
  `[q1.md #4](./q1.md)`.
- Research outputs go in `.ai.dump/<topic>/research.md` and SHOULD be linked
  from the Q file.
- Below each **Question:** block, MUST add an empty `**Answer:**` placeholder
  (see [Artifacts in general.md][artifacts]).
- SHOULD provide detailed analysis with reference links and concrete suggestions.
  MUST NOT waste tokens on praise, compliments, or discussing what works well.
- SHOULD update project docs (e.g., `docs/`) with resolved decisions; mark open
  items with links back to the Q file.

## Continuing a Discussion

When the user answers some questions and continues (e.g., `.` or "continue"):

1. Re-read the current `q<num>.md`.
2. Check for unanswered `**Answer:**` placeholders.
3. If unanswered questions remain:
   - Evaluate whether the new answers invalidate, expand, or make remaining
     questions irrelevant.
   - Revise or remove affected questions **in the same file**. Mark removed
     questions with ~~strikethrough~~ and a one-line reason.
   - Add new follow-up questions (if any) to the **same file**, below the
     existing questions.
   - MUST NOT create `q<num+1>.md` until every question in the current file is
     answered or struck through.
4. Only when all questions in the current file are resolved, create
   `q<num+1>.md` for the next round of follow-ups.

[artifacts]: ../general.md#artifacts
[rfc2119]: https://www.ietf.org/rfc/rfc2119.txt
