# Go Rules

Key words MUST, MUST NOT, SHOULD, and MAY follow [RFC 2119][rfc2119].

- SHOULD use modern Go features: generics, range-over-int (1.22+),
  `new(T(expr))` (1.26+), new std libs.
- SHOULD prefer direct field comparison over type conversion when types match.

[rfc2119]: https://www.ietf.org/rfc/rfc2119.txt
