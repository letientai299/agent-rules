# Writing Docs

Key words MUST, MUST NOT, SHOULD, and MAY follow [RFC 2119][rfc2119].

- MUST use **reference-style links** in Markdown, not inline. Keeps lines short.
  - Yes: `See [WhichKey][wk]` with `[wk]: https://...` at the bottom.
  - No: `See [WhichKey](https://github.com/folke/which-key.nvim)` inline.
- SHOULD use **mermaid** for diagrams, not ASCII art. SHOULD NOT overuse
  diagrams and tables (hard to maintain). Prefer clear text and lists.
- MUST NOT embed information that drifts as code changes (directory trees,
  version lists, counts, command output, etc.) in git-tracked docs. Instead,
  describe in prose, point to the source of truth, or generate at build time.
- MUST NOT restate code logic or inline comments in docs. Code is the source of
  truth; docs explain *why* and *how to navigate*, not *what the code does line
  by line*. Link to the relevant file instead of paraphrasing it.
- MUST NOT reference gitignored docs (e.g., `agents.local.md`, files in
  `.ai.dump/`) from git-tracked documentation. If their content is needed,
  consolidate the relevant information into the git-tracked docs instead.
- MUST NOT surround file paths in output with punctuation like `.` or `,` —
  write `path/to/file` not `path/to/file.` so double-click selects the full path
  for terminal use.

[rfc2119]: https://www.ietf.org/rfc/rfc2119.txt
