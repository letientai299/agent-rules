# Go Rules

Key words MUST, MUST NOT, SHOULD, and MAY follow [RFC 2119][rfc2119].

- SHOULD use modern Go features: generics, range-over-int (1.22+),
  `new(T(expr))` (1.26+), new std libs.
- SHOULD prefer direct field comparison over type conversion when types match.
- See [`data-modeling.md`][dm] for type design rules (sum types via interface +
  type switch, newtype pattern, value objects).

[dm]: ../data-modeling.md
[rfc2119]: https://www.ietf.org/rfc/rfc2119.txt
