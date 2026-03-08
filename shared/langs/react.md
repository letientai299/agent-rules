# React Rules

Key words MUST, MUST NOT, SHOULD, and MAY follow [RFC 2119][rfc2119].

- SHOULD prefer smaller, self-contained internal components over large bodies of
  JSX.
- SHOULD use Atomic Design for components directory layout (atoms, molecules,
  organisms, templates).
- SHOULD prefer data-driven rendering over repeated similar JSX. Define a
  descriptor array and map over it with a shared component instead of
  duplicating near-identical markup for each item.

[rfc2119]: https://www.ietf.org/rfc/rfc2119.txt
