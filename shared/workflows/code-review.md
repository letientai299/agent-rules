# Code Review

When the user asks to review code (PR, file, diff, or general review):

- Automatically write the full review to `.ai.dump/review-<topic>.md`.
- In conversation, give only a brief summary (critical count, top issue) and
  state the relative file path (e.g., `.ai.dump/review-auth.md`) so the user
  knows where to find it.

## Tone

Critical and constructive only. No praise, no compliments, no "looks good", no
softening language. Every sentence should identify a problem or suggest an
improvement.

## Structure

Organize findings by severity:

1. **Critical** — bugs, security vulnerabilities, data loss risks, crashes
2. **Important** — logic errors, missing edge cases, performance problems, API
   misuse
3. **Minor** — style violations, naming, readability, unnecessary complexity

## Format

- Reference specific `file:line` locations.
- Quote the problematic code snippet for **Critical** and **Important** findings
  only. For **Minor** findings, reference `file:line` without quoting — the
  description is sufficient.
- Explain why it's a problem. Add online valid reference links.
- Suggest a fix or direction.
- When multiple valid solutions exist with different trade-offs, list them all
  as **Options** with a short trade-off summary for each (e.g., simplicity vs
  performance, bundle size vs flexibility). This applies to both the reviewer
  (when writing findings) and the implementer (when fixing them). The chosen
  option should be marked; unchosen options stay as documentation for future
  reference.
- If the fix applied differs from the original suggestion, or a better approach
  emerges during implementation, document the **Alternative** inline with a
  brief rationale for why it's preferable (simpler, more performant, fewer side
  effects, etc.).

## Tracking

Each finding has a status. Update the review file as work progresses:

- **Open** — not yet addressed (default for new findings).
- **Fixed** — agent applied a fix. Note the commit or change briefly.
- **Won't fix** — agent judged the issue not worth fixing. Add a one-line
  rationale.
- **Deferred** — acknowledged but postponed. Link to a tracking issue if one
  exists.

Batch status updates — update all finding statuses in the review file once after
completing all fixes, not after each individual fix. This avoids repeated
reads/edits of the review file.
