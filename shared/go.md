# Go Rules

- Use modern Go features: generics, range-over-int (1.22+), `new(T(expr))`
  (1.26+), new std libs.
- Don't generate test code unnecessarily. Add tests only for new features and
  bug fixes.
- Prefer direct field comparison over type conversion when types match.
