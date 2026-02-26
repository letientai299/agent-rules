# Writing Docs

- Use **reference-style links** in Markdown, not inline. Keeps lines short.
  - Yes: `See [WhichKey][wk]` with `[wk]: https://...` at the bottom.
  - No: `See [WhichKey](https://github.com/folke/which-key.nvim)` inline.
- Use **mermaid** for diagrams, not ASCII art. Don't overuse diagrams and tables
  (hard to maintain). Prefer clear text and lists.
- When writing file paths in output (Q&A files, code reviews, research notes),
  don't surround them with punctuation like `.` or `,` — write `path/to/file`
  not `path/to/file.` so double-click selects the full path for terminal use
  (e.g., `nvim path/to/file`).
