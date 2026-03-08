# Code review requested

Key words MUST, MUST NOT, SHOULD, and MAY follow [RFC 2119][rfc2119].

When the user asks to review code (PR, file, diff, or general review):

- MUST write the full review to `.ai.dump/<topic>/review-r<num>.md` where
  `<num>` is the round number (r1, r2, r3, ...). MUST check existing files in
  `.ai.dump/<topic>/` to continue numbering.
- When writing round 2+, MUST cross-reference the previous round with a
  relative link at the top (e.g., `Previous round: [review-r1.md](./review-r1.md)`).
  MUST NOT copy findings from previous rounds — only reference them. Each
  round's file covers only new or unresolved findings.
- In conversation, MUST give only a brief summary (critical count, top issue)
  and state the relative `filepath:line` so the user can quickly jump to it.

## Tone

Critical and constructive only. MUST NOT praise, compliment, or soften. Every
sentence MUST identify a problem or suggest an improvement.

## Structure

MUST organize findings by severity:

1. **Critical** — bugs, security vulnerabilities, data loss risks, crashes
2. **Important** — logic errors, missing edge cases, performance problems, API
   misuse, DRY violations (duplicated logic), SRP violations (mixed concerns)
3. **Minor** — style violations, naming, readability, unnecessary complexity

## Format

- MUST reference specific `file:line` locations using relative paths from the
  workspace root (e.g., `src/utils/parse.ts:42`). In the review markdown file,
  MUST use relative-path links so the reader can navigate directly (e.g.,
  `[src/utils/parse.ts:42](../../src/utils/parse.ts)`).
- MUST quote the problematic code snippet for **Critical** and **Important**
  findings only. For **Minor** findings, reference `file:line` without quoting.
- MUST explain why it's a problem. SHOULD add online valid reference links.
- MUST suggest a fix or direction.
- When multiple valid solutions exist with different trade-offs, MUST list them
  all as **Options** with a short trade-off summary for each (e.g., simplicity
  vs performance, bundle size vs flexibility). The chosen option SHOULD be
  marked; unchosen options stay as documentation.
- If the fix applied differs from the original suggestion, MUST document the
  **Alternative** inline with a brief rationale.

## Verdicts

For each finding, MUST add an empty `**Answer:**` placeholder below the
suggested fix (see [Artifacts in general.md][artifacts]).

## Tracking

Each finding has a status. MUST update the review file as work progresses:

- **Open** — not yet addressed (default for new findings).
- **Fixed** — agent applied a fix. Note the commit or change briefly.
- **Won't fix** — agent judged the issue not worth fixing. Add a one-line
  rationale.
- **Deferred** — acknowledged but postponed. SHOULD link to a tracking issue.

MUST batch status updates — update all finding statuses in the review file once
after completing all fixes, not after each individual fix.

[artifacts]: ../general.md#artifacts
[rfc2119]: https://www.ietf.org/rfc/rfc2119.txt
