# Writing Docs

Key words MUST, MUST NOT, SHOULD, and MAY follow [RFC 2119][rfc2119].

- MUST use **reference-style links** in Markdown, not inline. Keeps lines short.
  - Yes: `See [WhichKey][wk]` with `[wk]: https://...` at the bottom.
  - No: `See [WhichKey](https://github.com/folke/which-key.nvim)` inline.
- SHOULD use **mermaid** for diagrams, not ASCII art. SHOULD NOT overuse
  diagrams and tables (hard to maintain). Prefer clear text and lists.
- MUST NOT surround file paths in output with punctuation like `.` or `,` —
  write `path/to/file` not `path/to/file.` so double-click selects the full path
  for terminal use.

[rfc2119]: https://www.ietf.org/rfc/rfc2119.txt
